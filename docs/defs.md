<!-- Generated with Stardoc: http://skydoc.bazel.build -->

User-facing rules for rules_bun.

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
MODULE.bazel). `bun_bundle` / `bun_compile` additionally take a `driver`
js_binary whose entry point is `@rules_bun//bun:bun-build-driver` and
whose `data` stages the build entry plus its full linked node_modules
closure — aspect_rules_js materializes that closure into the action's
runfiles so Bun resolves the import graph natively (no `bun install`).

<a id="bun_bundle"></a>

## bun_bundle

<pre>
load("@rules_bun//bun:defs.bzl", "bun_bundle")

bun_bundle(<a href="#bun_bundle-name">name</a>, <a href="#bun_bundle-out">out</a>, <a href="#bun_bundle-driver">driver</a>, <a href="#bun_bundle-entry">entry</a>, <a href="#bun_bundle-external">external</a>, <a href="#bun_bundle-format">format</a>, <a href="#bun_bundle-target">target</a>)
</pre>

Bundle a JS/TS entry into one file via the hermetic Bun toolchain.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun_bundle-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="bun_bundle-out"></a>out |  The single bundled output file (conventionally `*.mjs`).   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="bun_bundle-driver"></a>driver |  A `js_binary` whose entry point is `@rules_bun//bun:bun-build-driver` and whose `data` stages the bundle entry + its full linked node_modules closure. Run as the action executable so its runfiles materialize.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="bun_bundle-entry"></a>entry |  Path of the entry point relative to the driver's `_main` runfiles root (e.g. `packages/aion-cli/index.js`).   | String | required |  |
| <a id="bun_bundle-external"></a>external |  Module names to exclude from the bundle (passed as `--external <name>`, repeatable). Use for native addons and runtime `require`s that must stay external, e.g. `pg-native`, `@aws-sdk/*`, `encoding`, `source-map-support`.   | List of strings | optional |  `[]`  |
| <a id="bun_bundle-format"></a>format |  Bun `--format`. Defaults to `esm` so `import.meta` in deps stays valid under Node.   | String | optional |  `"esm"`  |
| <a id="bun_bundle-target"></a>target |  Bun `--target`: the intended execution environment for the bundle. Defaults to `node`.   | String | optional |  `"node"`  |


<a id="bun_compile"></a>

## bun_compile

<pre>
load("@rules_bun//bun:defs.bzl", "bun_compile")

bun_compile(<a href="#bun_compile-name">name</a>, <a href="#bun_compile-out">out</a>, <a href="#bun_compile-driver">driver</a>, <a href="#bun_compile-entry">entry</a>, <a href="#bun_compile-external">external</a>, <a href="#bun_compile-target">target</a>)
</pre>

Compile a JS/TS entry into a standalone native executable (Bun runtime + bundled JS) via `bun build --compile`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun_compile-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="bun_compile-out"></a>out |  The standalone executable output. On `--target bun-windows-*` give it a `.exe` suffix.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="bun_compile-driver"></a>driver |  A `js_binary` whose entry point is `@rules_bun//bun:bun-build-driver` and whose `data` stages the build entry + its full linked node_modules closure. Run as the action executable so its runfiles materialize.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="bun_compile-entry"></a>entry |  Path of the entry point relative to the driver's `_main` runfiles root (e.g. `apps/studio-cli/index.js`).   | String | required |  |
| <a id="bun_compile-external"></a>external |  Module names to keep external (`--external <name>`, repeatable). NOTE: native `.node` addons are NOT embedded by `--compile` — list them here and provide the `.node` files at runtime alongside the produced binary.   | List of strings | optional |  `[]`  |
| <a id="bun_compile-target"></a>target |  Bun compile target triple. Empty (the default) compiles for the host platform. Cross-compile values: `bun-linux-x64`, `bun-linux-x64-modern`, `bun-linux-x64-baseline`, `bun-linux-arm64`, `bun-darwin-x64`, `bun-darwin-arm64`, `bun-windows-x64`, and the `*-musl` libc variants (e.g. `bun-linux-x64-musl`). A future enhancement could derive this from the Bazel `--platforms` via a transition; for v1 pass the string.   | String | optional |  `""`  |


<a id="bun_test"></a>

## bun_test

<pre>
load("@rules_bun//bun:defs.bzl", "bun_test")

bun_test(<a href="#bun_test-name">name</a>, <a href="#bun_test-srcs">srcs</a>, <a href="#bun_test-data">data</a>)
</pre>

Run `bun test` over the listed source files as a Bazel test target.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="bun_test-srcs"></a>srcs |  Test files (typically `*.test.ts`, `*.test.js`). Each is passed to `bun test` explicitly so Bazel tracks them as inputs.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="bun_test-data"></a>data |  Additional runtime inputs (fixtures, bunfig.toml, etc.).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="BunBinaryInfo"></a>

## BunBinaryInfo

<pre>
load("@rules_bun//bun:defs.bzl", "BunBinaryInfo")

BunBinaryInfo(<a href="#BunBinaryInfo-binary">binary</a>, <a href="#BunBinaryInfo-target">target</a>)
</pre>

A standalone native executable produced by `bun build --compile`.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="BunBinaryInfo-binary"></a>binary |  File: the standalone executable.    |
| <a id="BunBinaryInfo-target"></a>target |  string: the Bun compile target triple (empty = host).    |


<a id="BunBundleInfo"></a>

## BunBundleInfo

<pre>
load("@rules_bun//bun:defs.bzl", "BunBundleInfo")

BunBundleInfo(<a href="#BunBundleInfo-bundle">bundle</a>, <a href="#BunBundleInfo-format">format</a>)
</pre>

A single-file bundle produced by `bun build`.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="BunBundleInfo-bundle"></a>bundle |  File: the bundled output.    |
| <a id="BunBundleInfo-format"></a>format |  string: the Bun output format (esm/cjs/iife).    |


<a id="BunTestInfo"></a>

## BunTestInfo

<pre>
load("@rules_bun//bun:defs.bzl", "BunTestInfo")

BunTestInfo(<a href="#BunTestInfo-result">result</a>)
</pre>

Result metadata for a `bun test` run.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="BunTestInfo-result"></a>result |  File: the captured test output (stdout + stderr concatenated).    |


<a id="bun_run"></a>

## bun_run

<pre>
load("@rules_bun//bun:defs.bzl", "bun_run")

bun_run(<a href="#bun_run-name">name</a>, <a href="#bun_run-script">script</a>, <a href="#bun_run-args">args</a>, <a href="#bun_run-kwargs">**kwargs</a>)
</pre>

Invoke `bun run <script>` against the live workspace source.

Escapes the runfiles sandbox via BUILD_WORKSPACE_DIRECTORY so Bun
resolves modules + reads files from the user's actual source tree.
Intentionally NOT hermetic — that's `bun_test`'s job.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="bun_run-name"></a>name |  target name.   |  none |
| <a id="bun_run-script"></a>script |  package-relative path to the Bun script entry point.   |  none |
| <a id="bun_run-args"></a>args |  extra args passed to `bun run` after the script name.   |  `None` |
| <a id="bun_run-kwargs"></a>kwargs |  forwarded to the underlying `sh_binary`.   |  none |


