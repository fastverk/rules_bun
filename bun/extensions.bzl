"""Module extensions for rules_bun.

Two extensions:

  * `bun` — auto-fetches a prebuilt Bun binary for the host platform.
    Versions are sha256-pinned in `private/known_versions.bzl`.
    Consumers can override via the `toolchain` tag class.

        bun = use_extension("@rules_bun//bun:extensions.bzl", "bun")
        use_repo(bun, "bun")
        register_toolchains("@bun//:bun_toolchain_def")

    Pin a specific version:

        bun.toolchain(version = "1.3.14")

  * `bun_deps` — Bun-native `node_modules` staging. Each `install` tag
    produces a repo `@<name>` whose `:node_modules` filegroup is a
    `bun install --frozen-lockfile`-ed tree. The pure-Bun replacement
    for aspect_rules_js's `npm_translate_lock` + `npm_link_all_packages`
    (no pnpm-lock, no aspect_rules_js):

        bun_deps = use_extension("@rules_bun//bun:extensions.bzl", "bun_deps")
        bun_deps.install(
            name = "npm",
            package_json = "//:package.json",
            lock = "//:bun.lock",
        )
        use_repo(bun_deps, "npm")

    then `bun_test(node_modules = "@npm//:node_modules", ...)` and
    `bun_bundle(node_modules = "@npm//:node_modules", ...)`.

The actual release fetching is delegated to
`@rules_github//github:repositories.bzl%github_binary_repository`
so that the URL-shape + sha-pinning logic stays consistent across
all our rules_* repos.
"""

load(
    "@rules_github//github:repositories.bzl",
    "github_binary_repository",
)
load("//bun/private:install.bzl", "bun_install")
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

# -----------------------------------------------------------------------------
# bun_deps — Bun-native node_modules staging (no pnpm-lock, no aspect_rules_js).
# -----------------------------------------------------------------------------

def _bun_deps_extension_impl(mctx):
    for mod in mctx.modules:
        for tag in mod.tags.install:
            bun_install(
                name = tag.name,
                package_json = tag.package_json,
                lock = tag.lock,
                bun_version = tag.bun_version,
                ignore_scripts = tag.ignore_scripts,
                trusted_dependencies = tag.trusted_dependencies,
                install_flags = tag.install_flags,
            )

_install_tag = tag_class(
    attrs = {
        "name": attr.string(
            mandatory = True,
            doc = "Name of the generated repo. Reference its node_modules as " +
                  "`@<name>//:node_modules`.",
        ),
        "package_json": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "The `package.json` to install from.",
        ),
        "lock": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "The `bun.lock` pinning the install (`--frozen-lockfile`).",
        ),
        "bun_version": attr.string(
            default = "",
            doc = "Bun version to fetch for the install. Empty = the toolchain " +
                  "extension's default.",
        ),
        "ignore_scripts": attr.bool(
            default = True,
            doc = "Skip dependency lifecycle scripts (`--ignore-scripts`). " +
                  "Default True.",
        ),
        "trusted_dependencies": attr.string_list(
            default = [],
            doc = "Packages to `--trust` (run lifecycle scripts for) even " +
                  "when `ignore_scripts` is True.",
        ),
        "install_flags": attr.string_list(
            default = [],
            doc = "Extra raw flags appended to `bun install`.",
        ),
    },
    doc = "Stage a node_modules tree from a package.json + bun.lock.",
)

bun_deps = module_extension(
    implementation = _bun_deps_extension_impl,
    tag_classes = {"install": _install_tag},
    doc = "Bun-native node_modules staging — `@<name>//:node_modules` from a " +
          "`bun install --frozen-lockfile`. Replaces aspect_rules_js's " +
          "npm_translate_lock + npm_link_all_packages for pure-Bun repos.",
)
