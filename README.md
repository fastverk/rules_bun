# rules_bun

Bazel rules for [Bun](https://bun.sh/). Fetches the prebuilt Bun binary,
wraps it as a Bazel toolchain, and provides hermetic `bun test` +
sandbox-escaping `bun run` runners.

- **module extension**: `bun` — auto-creates `@bun` with the host-platform binary. See [docs/extensions.md](docs/extensions.md).
- **toolchain**: `bun_toolchain` — wraps the binary; resolved via `@rules_bun//bun:toolchain_type`. See [docs/toolchains.md](docs/toolchains.md).
- **rules**:
  - `bun_test` — runs `bun test` over listed source files as a Bazel test target.
  - `bun_run` — `bazel run //path:target` macro: invokes `bun run <script>` against the live workspace source.

  See [docs/defs.md](docs/defs.md).

## Install

Add the registry to your `.bazelrc`:

```
common --registry=https://raw.githubusercontent.com/fastverk/bazel-registry/main/
common --registry=https://bcr.bazel.build/
```

In your `MODULE.bazel`:

```python
bazel_dep(name = "rules_bun", version = "0.1.0")

bun = use_extension("@rules_bun//bun:extensions.bzl", "bun")
use_repo(bun, "bun")
register_toolchains("@bun//:bun_toolchain_def")
```

Pin a specific version:

```python
bun.toolchain(version = "1.3.14")
```

## Quick start

Hermetic tests:

```python
load("@rules_bun//bun:defs.bzl", "bun_test")

bun_test(
    name = "math_tests",
    srcs = glob(["*.test.ts"]),
    data = ["bunfig.toml"],
)
```

`bazel test //:math_tests` runs `bun test <each src>` with `NO_COLOR=1` + `DO_NOT_TRACK=1` set.

Dev runner:

```python
load("@rules_bun//bun:defs.bzl", "bun_run")

bun_run(
    name = "build",
    script = "scripts/build.ts",
)
```

`bazel run //:build -- --watch` invokes `bun run scripts/build.ts --watch` against your live workspace source (not the Bazel sandbox). Useful for the dev loop where you want HMR / on-demand module resolution / filesystem watch outside the runfiles tree.

## How it works

The module extension fetches a sha-pinned Bun binary for the host platform from [oven-sh/bun GitHub releases](https://github.com/oven-sh/bun/releases). The release zip extracts to `bun-<platform>/bun`; the repository rule strips the outer dir so the binary lands at `@bun//:bun`.

`bun_toolchain` wraps that binary as a Bazel toolchain. `bun_test` resolves the toolchain via `@rules_bun//bun:toolchain_type` and runs `bun test` over each src in a runfiles-staged sandbox. `bun_run` is a macro that emits a `sh_binary` escaping the sandbox to run against `BUILD_WORKSPACE_DIRECTORY` directly.

### Hermeticity + determinism

| Layer            | Pinned by                                                       |
| ---------------- | --------------------------------------------------------------- |
| Bun binary       | `sha256` in [`bun/private/known_versions.bzl`](bun/private/known_versions.bzl) per `(version, platform)` |
| Test env         | `bun_test` sets `NO_COLOR=1`, `DO_NOT_TRACK=1`, `BUN_INSTALL_NO_TRACK=1` |
| `bun_run` env    | same, with `NO_COLOR` overridable for callers that want colored output |

`bun_run` is **intentionally non-hermetic** — Bun's dev mode (HMR, watch, on-demand module resolution) needs filesystem access outside the runfiles tree. Counterpart to `bun_test`'s hermetic execution.

## Compatibility

- **Bazel**: 7.4+, bzlmod required.
- **Bun**: 1.3.14 pinned by default. Bump via `known_versions.bzl`.
- **Platforms**: `darwin-aarch64`, `darwin-x64`, `linux-aarch64`, `linux-x64`. Baseline + musl + Windows variants doable — add an entry to the table when needed.

## Contributing

Reference docs (`docs/{defs,extensions,toolchains}.md`) are stardoc-generated. After editing rule docstrings:

```sh
bazel run //docs:update
```

CI gates this via `bazel test //docs/...`.

## License

MIT.
