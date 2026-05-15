"""Module extension for rules_bun.

Auto-fetches a prebuilt Bun binary for the host platform. Versions
are sha256-pinned in `private/known_versions.bzl`. Consumers can
override via the `toolchain` tag class.

Default usage:

    bun = use_extension("@rules_bun//bun:extensions.bzl", "bun")
    use_repo(bun, "bun")
    register_toolchains("@bun//:bun_toolchain_def")

Pin a specific version:

    bun.toolchain(version = "1.3.14")

The actual release fetching is delegated to
`@rules_github//github:repositories.bzl%github_binary_repository`
so that the URL-shape + sha-pinning logic stays consistent across
all our rules_* repos.
"""

load(
    "@rules_github//github:repositories.bzl",
    "github_binary_repository",
)
load(
    "//bun/private:known_versions.bzl",
    "DEFAULT_VERSION",
    "KNOWN_VERSIONS",
)

# Canonical (rules_github) -> Bun-release asset platform name.
# Bun's release assets are named e.g. `bun-darwin-aarch64.zip`,
# `bun-linux-x64.zip` (note `-x64`, not `-x86_64`).
_PLATFORM_ALIASES = {
    "darwin_aarch64": "darwin-aarch64",
    "darwin_x86_64": "darwin-x64",
    "linux_aarch64": "linux-aarch64",
    "linux_x86_64": "linux-x64",
}

_BUN_BUILD = """\
load("@rules_bun//bun:toolchains.bzl", "bun_toolchain")

package(default_visibility = ["//visibility:public"])

exports_files(["bun"])

bun_toolchain(
    name = "bun_toolchain",
    bun = ":bun",
)

toolchain(
    name = "bun_toolchain_def",
    toolchain = ":bun_toolchain",
    toolchain_type = "@rules_bun//bun:toolchain_type",
)
"""

def _bun_extension_impl(mctx):
    version = DEFAULT_VERSION
    for mod in mctx.modules:
        for tag in mod.tags.toolchain:
            if tag.version:
                version = tag.version

    github_binary_repository(
        name = "bun",
        repo = "oven-sh/bun",
        version = version,
        # Bun tags releases as `bun-v<version>` (not `v<version>`).
        tag_format = "bun-v{version}",
        asset_template = "bun-{platform}.zip",
        # Asset extracts to `bun-<platform>/bun`; strip the outer dir.
        strip_prefix_template = "bun-{platform}",
        platform_aliases = _PLATFORM_ALIASES,
        platform_shas = KNOWN_VERSIONS.get(version, {}),
        # Unpinned versions emit a warning instead of failing — keeps
        # `bun.toolchain(version = "<new>")` ergonomic for bumps.
        allow_unverified = True,
        build_file_content = _BUN_BUILD,
    )

_toolchain_tag = tag_class(attrs = {
    "version": attr.string(
        default = "",
        doc = "Override Bun version. Defaults to the value in known_versions.bzl.",
    ),
})

bun = module_extension(
    implementation = _bun_extension_impl,
    tag_classes = {"toolchain": _toolchain_tag},
    doc = "Sets up @bun as a Bazel-fetched prebuilt Bun binary.",
)
