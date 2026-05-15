<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Module extension for rules_bun.

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

<a id="bun"></a>

## bun

<pre>
bun = use_extension("@rules_bun//bun:extensions.bzl", "bun")
bun.toolchain(<a href="#bun.toolchain-version">version</a>)
</pre>

Sets up @bun as a Bazel-fetched prebuilt Bun binary.


**TAG CLASSES**

<a id="bun.toolchain"></a>

### toolchain

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun.toolchain-version"></a>version |  Override Bun version. Defaults to the value in known_versions.bzl.   | String | optional |  `""`  |


