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
"""

load(
    "//bun/private:known_versions.bzl",
    "DEFAULT_VERSION",
    "KNOWN_VERSIONS",
    "URL_TEMPLATE",
)

def _resolve_platform(rctx):
    os = rctx.os.name.lower()
    arch = rctx.os.arch.lower()
    if "linux" in os and arch in ("x86_64", "amd64"):
        return "linux-x64"
    if "linux" in os and arch in ("aarch64", "arm64"):
        return "linux-aarch64"
    if ("mac" in os or "darwin" in os) and arch in ("aarch64", "arm64"):
        return "darwin-aarch64"
    if ("mac" in os or "darwin" in os) and arch in ("x86_64", "amd64"):
        return "darwin-x64"
    fail("rules_bun: unsupported platform os=%s arch=%s" % (os, arch))

def _bun_repo_impl(rctx):
    platform = _resolve_platform(rctx)
    version = rctx.attr.version
    sha = KNOWN_VERSIONS.get(version, {}).get(platform, "")
    url = URL_TEMPLATE.format(version = version, platform = platform)
    if not sha:
        # buildifier: disable=print
        print(("rules_bun: WARNING — no pinned sha256 for bun@{v} on {p}; " +
               "downloading unverified. Add an entry to known_versions.bzl " +
               "for hermetic builds.").format(v = version, p = platform))

    rctx.download_and_extract(
        url = url,
        sha256 = sha or "",
        # The release zip extracts to `bun-<platform>/bun`. We strip the
        # outer dir so the binary lands at the repo root as `bun`.
        stripPrefix = "bun-" + platform,
    )

    # Generated BUILD.bazel exposing the binary + a Bun toolchain.
    rctx.file("BUILD.bazel", """\
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
""")

_bun_repository = repository_rule(
    implementation = _bun_repo_impl,
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "Bun release version (e.g. \"1.3.14\"; no leading `v`).",
        ),
    },
)

def _bun_extension_impl(mctx):
    version = DEFAULT_VERSION
    for mod in mctx.modules:
        for tag in mod.tags.toolchain:
            if tag.version:
                version = tag.version
    _bun_repository(name = "bun", version = version)

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
