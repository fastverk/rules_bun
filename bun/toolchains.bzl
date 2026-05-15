"""Toolchain rule for rules_bun.

`bun_toolchain` wraps a single Bun binary as a Bazel toolchain.
Consumers (the `bun_test` and `bun_run` rules) resolve Bun through
`@rules_bun//bun:toolchain_type`, so users can register custom Bun
binaries (locally-built fork, alternate version, baseline-CPU
variant) via `register_toolchains(...)` without modifying rule
attrs.

The module extension at `@rules_bun//bun:extensions.bzl` generates a
default toolchain (`@bun//:bun_toolchain_def`) wrapping the prebuilt
binary. Users register it from `MODULE.bazel`:

    register_toolchains("@bun//:bun_toolchain_def")
"""

BunToolchainInfo = provider(
    doc = "The Bun binary, resolved via a toolchain.",
    fields = {
        "bun": "File: the bun executable.",
    },
)

def _bun_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        buninfo = BunToolchainInfo(
            bun = ctx.file.bun,
        ),
    )]

bun_toolchain = rule(
    implementation = _bun_toolchain_impl,
    attrs = {
        "bun": attr.label(
            allow_single_file = True,
            mandatory = True,
            cfg = "exec",
            doc = "Path to the Bun executable.",
        ),
    },
    doc = "Declare a Bun binary as a Bazel toolchain.",
)
