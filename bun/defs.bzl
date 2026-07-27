"""User-facing rules for rules_bun.

Four pieces:

  * `bun_test` — runs `bun test` as a hermetic Bazel test action with
    explicit srcs + deps. Returns a `BunTestInfo` provider wrapping
    the test result file (for downstream consumers; the main consumer
    is the test framework, which only cares about exit codes).

  * `bun_run` — sh_binary macro: `bazel run //path:NAME` invokes
    `bun run <script>` against the live workspace source. Intentionally
    non-hermetic (escapes the runfiles sandbox) for the dev loop.
    Counterpart to `bun_test`'s hermetic execution.

  * `bun_bundle` — bundle a JS/TS entry point into one self-contained
    file with `bun build`. Returns `BunBundleInfo`.

  * `bun_compile` — compile a JS/TS entry point into a standalone native
    executable with `bun build --compile` (Bun runtime + bundled JS).
    Returns `BunBinaryInfo` and is `bazel run`-nable.

All resolve the Bun binary via `@rules_bun//bun:toolchain_type` (set
up by `register_toolchains("@bun//:bun_toolchain_def")` in your
MODULE.bazel).

`bun_bundle` / `bun_compile` have two ways to provision node_modules:

  * Bun-native (recommended; no aspect_rules_js, no pnpm-lock): pass a
    `node_modules` label (a `@<name>//:node_modules` from a
    `bun_deps.install` tag — see `extensions.bzl`) plus `srcs` (the entry
    + local modules). `bun build` runs directly via the toolchain Bun; a
    small shell driver stages the entry into a real tree and symlinks the
    closure so Bun resolves the import graph natively.

  * Legacy aspect_rules_js: pass a `driver` js_binary whose entry point
    is `@rules_bun//bun:bun-build-driver` and whose `data` stages the
    build entry plus its full linked node_modules closure; aspect
    materializes that closure into the action runfiles.

`driver` and `node_modules` are mutually exclusive — set exactly one.
`bun_test` likewise takes an optional `node_modules` for dep resolution.
"""

load("@rules_shell//shell:sh_binary.bzl", _sh_binary = "sh_binary")

BunTestInfo = provider(
    doc = "Result metadata for a `bun test` run.",
    fields = {
        "result": "File: the captured test output (stdout + stderr concatenated).",
    },
)

# -----------------------------------------------------------------------------
# bun_test — hermetic `bun test` as a Bazel test.
# -----------------------------------------------------------------------------

def _pick_node_modules_parent(ctx, paths):
    """Choose the dir CONTAINING the `node_modules` the CONSUMER should resolve against.

    With an aspect_rules_js closure the filegroup carries TWO kinds of path:

      <bin>/<package>/node_modules/<pkg>                  the consumer's flat links
      <bin>/node_modules/.aspect_rules_js/<pkg>@<v>/...   the shared package store

    Only the first resolves bare imports; the store holds versioned directories.
    Taking whichever appears first is a coin flip, and in a monorepo the store
    usually wins — every `import "react"` then fails to resolve, because the
    driver symlinks a tree with no flat links in it.

    This was invisible while each consumer was its own workspace root: there
    `<package>` is "" so both forms collapse to `<bin>`, and the store doubled as
    the link tree. Once consumers are nested packages the two diverge.

    So: prefer the candidate ending in the consuming package's path, and fall
    back to the first match, which preserves the old behaviour for a root-package
    consumer and for the Bun-native `@<name>//:node_modules` case (an external
    repo root, where no candidate carries the package suffix).
    """
    suffix = "/" + ctx.label.package if ctx.label.package else ""
    fallback = ""
    for p in paths:
        idx = p.find("/node_modules/")
        if idx == -1:
            continue
        parent = p[:idx]
        if suffix and parent.endswith(suffix):
            return parent
        if not fallback:
            fallback = parent
    return fallback

def _node_modules_parent_short(ctx):
    """The runfiles-root-relative dir CONTAINING the `node_modules` closure.

    The `node_modules` filegroup's files live in an external repo, so their
    `short_path` is `../<canonical>/node_modules/<pkg>/...`. Return the prefix
    up to (not including) the `node_modules/` component, runfiles-relative, so
    the runner can symlink that dir's `node_modules` into the test staging
    tree. ("" when no node_modules given.)
    """
    if not ctx.attr.node_modules:
        return "", []
    return _pick_node_modules_parent(
        ctx,
        [f.short_path for f in ctx.files.node_modules],
    ), ctx.files.node_modules

def _bun_test_impl(ctx):
    bun = ctx.toolchains["@rules_bun//bun:toolchain_type"].buninfo.bun

    # Bun's test runner accepts a list of files / glob patterns. We
    # pass all `srcs` explicitly so Bazel sees the exact inputs.
    test_args = [src.short_path for src in ctx.files.srcs]

    nm_parent, nm_files = _node_modules_parent_short(ctx)

    # Build the runner script. Bun reads `bunfig.toml` from the cwd if
    # present; we put it in the sandbox alongside the test files so
    # consumers' bunfig is honored.
    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = runner,
        is_executable = True,
        content = """\
#!/usr/bin/env bash
# Generated by bun_test.
set -euo pipefail

RUNFILES_DIR="${{RUNFILES_DIR:-$0.runfiles}}"
# Under bzlmod the toolchain Bun is an external repo file, so its
# short_path is `../rules_bun++bun+bun/bun`. Runfiles are rooted at the
# main repo (`_main/`), so prefix with `_main/` — the embedded `../`
# then resolves back out to the sibling external repo dir. (Without the
# `_main/` prefix the `../` escapes the runfiles tree entirely.)
BUN_BIN="${{RUNFILES_DIR}}/_main/{bun_short}"
if [[ ! -x "$BUN_BIN" ]]; then
  # Fallback for workspaces with non-default repo names. `-L` follows
  # the runfiles symlink to the real (executable) Bun binary.
  BUN_BIN="$(find -L "$RUNFILES_DIR" -name bun -type f -perm -u+x | head -1)"
fi

# Determinism + telemetry pins.
export NO_COLOR=1
export DO_NOT_TRACK=1
export BUN_INSTALL_NO_TRACK=1

WORKSPACE_ROOT="${{RUNFILES_DIR}}/_main"
NM_PARENT="{nm_parent}"

if [[ -n "$NM_PARENT" ]]; then
  # `node_modules` was provided. Bazel stages the test files as SYMLINKS into
  # the read-only source tree; `bun test` resolves a test file's realpath and
  # then looks for `node_modules` next to that REAL file (in the workspace,
  # where there is none). So materialize a real staging tree: copy each test
  # file (dereferencing the symlink) to its workspace-relative path, symlink
  # the staged node_modules at the staging root, and run from there so Bun
  # walks up from the (real) test file into the (real) node_modules.
  STAGE="$(mktemp -d "${{TMPDIR:-/tmp}}/bun_test.XXXXXX")"
  trap 'rm -rf "$STAGE"' EXIT
  for f in {test_args}; do
    mkdir -p "$STAGE/$(dirname "$f")"
    cp -L "${{WORKSPACE_ROOT}}/$f" "$STAGE/$f"
  done
  # NM_PARENT is the closure's short_path prefix (`../<canonical>` for an
  # external repo). As with BUN_BIN, prefix `_main/` so the embedded `../`
  # resolves back out to the sibling external repo dir under RUNFILES_DIR.
  NM_SRC="${{WORKSPACE_ROOT}}/${{NM_PARENT}}/node_modules"
  if [[ ! -d "$NM_SRC" ]]; then
    # Fallback for non-default repo names: locate the staged node_modules.
    NM_SRC="$(find -L "$RUNFILES_DIR" -type d -name node_modules | head -1)"
  fi
  ln -s "$NM_SRC" "$STAGE/node_modules"
  cd "$STAGE"
else
  # No node_modules: run from the workspace runfiles root (back-compat).
  cd "$WORKSPACE_ROOT"
fi

exec "$BUN_BIN" test {test_args}
""".format(
            bun_short = bun.short_path,
            nm_parent = nm_parent,
            test_args = " ".join(['"' + a + '"' for a in test_args]),
        ),
    )

    runfiles = ctx.runfiles(
        files = [bun] + ctx.files.srcs + ctx.files.data + nm_files,
    )
    return [
        DefaultInfo(executable = runner, runfiles = runfiles),
    ]

bun_test = rule(
    implementation = _bun_test_impl,
    test = True,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            mandatory = True,
            doc = "Test files (typically `*.test.ts`, `*.test.js`). Each is " +
                  "passed to `bun test` explicitly so Bazel tracks them as " +
                  "inputs.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Additional runtime inputs (fixtures, bunfig.toml, etc.).",
        ),
        "node_modules": attr.label(
            allow_files = True,
            doc = "Optional `node_modules` closure (typically " +
                  "`@<name>//:node_modules` from a `bun_deps.install` tag). " +
                  "Staged at the workspace runfiles root as `node_modules/` so " +
                  "`bun test` resolves dependency imports without `bun install`. " +
                  "The Bun-native replacement for aspect_rules_js's " +
                  "`npm_link_all_packages`.",
        ),
    },
    toolchains = ["@rules_bun//bun:toolchain_type"],
    doc = "Run `bun test` over the listed source files as a Bazel test target.",
)

# -----------------------------------------------------------------------------
# bun_run — sh_binary wrapper around `bun run <script>`.
# -----------------------------------------------------------------------------

def bun_run(name, script, args = None, **kwargs):
    """Invoke `bun run <script>` against the live workspace source.

    Escapes the runfiles sandbox via BUILD_WORKSPACE_DIRECTORY so Bun
    resolves modules + reads files from the user's actual source tree.
    Intentionally NOT hermetic — that's `bun_test`'s job.

    Args:
      name: target name.
      script: package-relative path to the Bun script entry point.
      args: extra args passed to `bun run` after the script name.
      **kwargs: forwarded to the underlying `sh_binary`.
    """
    extra = " ".join(args) if args else ""
    _sh_binary(
        name = name,
        srcs = ["@rules_bun//bun/private:bun_run.sh"],
        data = ["@bun//:bun"],
        env = {
            "BUN_RUN_SCRIPT": script,
            "BUN_RUN_EXTRA_ARGS": extra,
        },
        **kwargs
    )

# -----------------------------------------------------------------------------
# bun_bundle / bun_compile — `bun build` driven via a js_binary driver.
# -----------------------------------------------------------------------------

BunBundleInfo = provider(
    doc = "A single-file bundle produced by `bun build`.",
    fields = {
        "bundle": "File: the bundled output.",
        "format": "string: the Bun output format (esm/cjs/iife).",
    },
)

BunBinaryInfo = provider(
    doc = "A standalone native executable produced by `bun build --compile`.",
    fields = {
        "binary": "File: the standalone executable.",
        "target": "string: the Bun compile target triple (empty = host).",
    },
)

def _driver_args(ctx, out, compile):
    """Build the shared `bun-build-driver` arg list for an action.

    The driver (a js_binary) does NOT chdir into the `_main` runfiles root, so
    `--bun` and `--out` are passed execroot-relative; the driver re-anchors them
    on `$JS_BINARY__EXECROOT` (absolute) so they survive its own chdir into the
    workspace runfiles root. `--entry` stays relative to that runfiles root.
    """
    args = ctx.actions.args()
    bun = ctx.toolchains["@rules_bun//bun:toolchain_type"].buninfo.bun
    args.add("--bun", bun.path)
    args.add("--entry", ctx.attr.entry)
    args.add("--out", out.path)
    args.add("--format", ctx.attr.format if hasattr(ctx.attr, "format") else "esm")
    args.add("--target", ctx.attr.target)
    for ext in ctx.attr.external:
        args.add("--external", ext)
    if compile:
        args.add("--compile")
    return args, bun

def _node_modules_parent(ctx):
    """The execroot-relative dir CONTAINING the staged `node_modules`.

    The `node_modules` filegroup's files live at `<parent>/node_modules/...`
    in the execroot (for `@npm//:node_modules`, `<parent>` is the external
    repo root). The native build driver symlinks `<parent>/node_modules` to
    `./node_modules` at the execroot root so Bun's resolver walks up into it.
    Returns ("" , []) when no node_modules is given.
    """
    if not ctx.attr.node_modules:
        return "", []
    return _pick_node_modules_parent(
        ctx,
        [f.path for f in ctx.files.node_modules],
    ), ctx.files.node_modules

def _native_build(ctx, out, compile, mnemonic, progress):
    """Run `bun build` directly via the toolchain — no js_binary, no aspect.

    Stages the entry (+ local srcs) and the `node_modules` closure as action
    inputs and shells through `bun_build_native.sh`, which symlinks
    node_modules to the execroot root before invoking Bun.
    """
    bun = ctx.toolchains["@rules_bun//bun:toolchain_type"].buninfo.bun
    nm_parent, nm_files = _node_modules_parent(ctx)

    # The build entry + local modules, as workspace-relative paths the driver
    # copies into a real staging tree (Bazel stages them as symlinks into the
    # read-only source tree, which Bun's realpath resolver would otherwise
    # escape — see bun_build_native.sh).
    srcs_list = "\n".join([s.short_path for s in ctx.files.srcs])

    args = ctx.actions.args()
    args.add(bun.path)
    args.add(ctx.attr.entry)
    args.add(out.path)
    args.add(nm_parent)
    args.add("compile" if compile else "bundle")
    args.add(ctx.attr.format if hasattr(ctx.attr, "format") else "esm")
    args.add(ctx.attr.target)
    args.add(srcs_list)
    for ext in ctx.attr.external:
        args.add("--external")
        args.add(ext)

    ctx.actions.run(
        outputs = [out],
        inputs = depset([bun] + ctx.files.srcs + nm_files),
        executable = ctx.executable._native_driver,
        arguments = [args],
        mnemonic = mnemonic,
        progress_message = "%s %s with Bun (native)" % (progress, ctx.label),
    )

def _bun_bundle_impl(ctx):
    out = ctx.outputs.out
    _validate_build_mode(ctx)

    if ctx.attr.node_modules or not ctx.attr.driver:
        _native_build(ctx, out, compile = False, mnemonic = "BunBundle", progress = "Bundling")
    else:
        args, bun = _driver_args(ctx, out, compile = False)
        ctx.actions.run(
            outputs = [out],
            inputs = [bun],
            executable = ctx.executable.driver,
            arguments = [args],
            # aspect_rules_js's js_binary launcher reads BAZEL_BINDIR at startup.
            # "." keeps it at the `_main` runfiles root, where the linked
            # node_modules + the bundle entry are staged.
            env = {"BAZEL_BINDIR": "."},
            mnemonic = "BunBundle",
            progress_message = "Bundling %s with Bun" % ctx.label,
        )

    return [
        DefaultInfo(files = depset([out])),
        BunBundleInfo(bundle = out, format = ctx.attr.format),
    ]

def _validate_build_mode(ctx):
    """Require exactly one build path: `driver` (aspect) xor `node_modules` (native)."""
    if ctx.attr.driver and ctx.attr.node_modules:
        fail(("%s: set EITHER `driver` (aspect_rules_js path) OR " +
              "`node_modules` (Bun-native path), not both.") % ctx.label)
    if not ctx.attr.driver and not ctx.attr.node_modules:
        fail(("%s: set `node_modules` (a `@<name>//:node_modules` from " +
              "`bun_deps.install`) for the Bun-native path, or `driver` (a " +
              "js_binary) for the legacy aspect_rules_js path.") % ctx.label)

bun_bundle = rule(
    implementation = _bun_bundle_impl,
    attrs = {
        "driver": attr.label(
            executable = True,
            cfg = "target",
            doc = "LEGACY aspect_rules_js path. A `js_binary` whose entry " +
                  "point is `@rules_bun//bun:bun-build-driver` and whose " +
                  "`data` stages the bundle entry + its full linked " +
                  "node_modules closure. Mutually exclusive with " +
                  "`node_modules`; set exactly one.",
        ),
        "node_modules": attr.label(
            allow_files = True,
            doc = "Bun-native path. A `node_modules` closure (typically " +
                  "`@<name>//:node_modules` from a `bun_deps.install` tag). " +
                  "When set, `bun build` runs directly via the toolchain Bun " +
                  "(no js_binary driver, no aspect_rules_js): the closure is " +
                  "symlinked to the execroot root so Bun resolves the import " +
                  "graph by walking up from `entry`. Mutually exclusive with " +
                  "`driver`. Pair with `srcs` (the entry + local modules).",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            default = [],
            doc = "Bun-native path. The entry file + any local modules it " +
                  "imports, declared as action inputs. Ignored on the legacy " +
                  "`driver` path (that stages sources via the js_binary's " +
                  "`data`).",
        ),
        "entry": attr.string(
            mandatory = True,
            doc = "Path of the entry point relative to the workspace root " +
                  "(e.g. `packages/aion-cli/index.js`). On the native path " +
                  "this is the execroot-relative path; on the legacy path it " +
                  "is relative to the driver's `_main` runfiles root (same " +
                  "string in practice).",
        ),
        "out": attr.output(
            mandatory = True,
            doc = "The single bundled output file (conventionally `*.mjs`).",
        ),
        "format": attr.string(
            default = "esm",
            values = ["esm", "cjs", "iife"],
            doc = "Bun `--format`. Defaults to `esm` so `import.meta` in deps " +
                  "stays valid under Node.",
        ),
        "target": attr.string(
            default = "node",
            values = ["node", "browser", "bun"],
            doc = "Bun `--target`: the intended execution environment for the " +
                  "bundle. Defaults to `node`.",
        ),
        "external": attr.string_list(
            default = [],
            doc = "Module names to exclude from the bundle (passed as " +
                  "`--external <name>`, repeatable). Use for native addons and " +
                  "runtime `require`s that must stay external, e.g. " +
                  "`pg-native`, `@aws-sdk/*`, `encoding`, `source-map-support`.",
        ),
        "_native_driver": attr.label(
            default = "@rules_bun//bun/private:bun_build_native",
            executable = True,
            cfg = "exec",
            doc = "The Bun-native (no-aspect) build driver shell script.",
        ),
    },
    toolchains = ["@rules_bun//bun:toolchain_type"],
    doc = "Bundle a JS/TS entry into one file via the hermetic Bun toolchain. " +
          "Either Bun-native (`node_modules` from `bun_deps.install`, no " +
          "aspect_rules_js) or the legacy aspect `driver` js_binary path.",
)

def _bun_compile_impl(ctx):
    out = ctx.outputs.out
    _validate_build_mode(ctx)

    if ctx.attr.node_modules or not ctx.attr.driver:
        _native_build(ctx, out, compile = True, mnemonic = "BunCompile", progress = "Compiling")
    else:
        args, bun = _driver_args(ctx, out, compile = True)
        ctx.actions.run(
            outputs = [out],
            inputs = [bun],
            executable = ctx.executable.driver,
            arguments = [args],
            env = {"BAZEL_BINDIR": "."},
            mnemonic = "BunCompile",
            progress_message = "Compiling %s with Bun" % ctx.label,
        )

    return [
        # The output is itself the runnable executable, so `bazel run` works.
        DefaultInfo(files = depset([out]), executable = out),
        BunBinaryInfo(binary = out, target = ctx.attr.target),
    ]

bun_compile = rule(
    implementation = _bun_compile_impl,
    executable = True,
    attrs = {
        "driver": attr.label(
            executable = True,
            cfg = "target",
            doc = "LEGACY aspect_rules_js path. A `js_binary` whose entry " +
                  "point is `@rules_bun//bun:bun-build-driver` and whose " +
                  "`data` stages the build entry + its full linked " +
                  "node_modules closure. Mutually exclusive with " +
                  "`node_modules`; set exactly one.",
        ),
        "node_modules": attr.label(
            allow_files = True,
            doc = "Bun-native path. A `node_modules` closure (typically " +
                  "`@<name>//:node_modules` from a `bun_deps.install` tag). " +
                  "When set, `bun build --compile` runs directly via the " +
                  "toolchain Bun (no js_binary driver, no aspect_rules_js). " +
                  "Mutually exclusive with `driver`. Pair with `srcs`.",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            default = [],
            doc = "Bun-native path. The entry file + any local modules it " +
                  "imports, declared as action inputs. Ignored on the legacy " +
                  "`driver` path.",
        ),
        "entry": attr.string(
            mandatory = True,
            doc = "Path of the entry point relative to the workspace root " +
                  "(e.g. `apps/studio-cli/index.js`).",
        ),
        "out": attr.output(
            mandatory = True,
            doc = "The standalone executable output. On `--target " +
                  "bun-windows-*` give it a `.exe` suffix.",
        ),
        "target": attr.string(
            default = "",
            doc = "Bun compile target triple. Empty (the default) compiles " +
                  "for the host platform. Cross-compile values: " +
                  "`bun-linux-x64`, `bun-linux-x64-modern`, " +
                  "`bun-linux-x64-baseline`, `bun-linux-arm64`, " +
                  "`bun-darwin-x64`, `bun-darwin-arm64`, `bun-windows-x64`, " +
                  "and the `*-musl` libc variants (e.g. `bun-linux-x64-musl`). " +
                  "A future enhancement could derive this from the Bazel " +
                  "`--platforms` via a transition; for v1 pass the string.",
        ),
        "external": attr.string_list(
            default = [],
            doc = "Module names to keep external (`--external <name>`, " +
                  "repeatable). NOTE: native `.node` addons are NOT embedded " +
                  "by `--compile` — list them here and provide the `.node` " +
                  "files at runtime alongside the produced binary.",
        ),
        "_native_driver": attr.label(
            default = "@rules_bun//bun/private:bun_build_native",
            executable = True,
            cfg = "exec",
            doc = "The Bun-native (no-aspect) build driver shell script.",
        ),
    },
    toolchains = ["@rules_bun//bun:toolchain_type"],
    doc = "Compile a JS/TS entry into a standalone native executable " +
          "(Bun runtime + bundled JS) via `bun build --compile`. Either " +
          "Bun-native (`node_modules`) or the legacy aspect `driver` path.",
)
