<!-- Generated with Stardoc: http://skydoc.bazel.build -->

User-facing rules for rules_bun.

Two pieces:

  * `bun_test` — runs `bun test` as a hermetic Bazel test action with
    explicit srcs + deps. Returns a `BunTestInfo` provider wrapping
    the test result file (for downstream consumers; the main consumer
    is the test framework, which only cares about exit codes).

  * `bun_run` — sh_binary macro: `bazel run //path:NAME` invokes
    `bun run <script>` against the live workspace source. Intentionally
    non-hermetic (escapes the runfiles sandbox) for the dev loop.
    Counterpart to `bun_test`'s hermetic execution.

Both resolve the Bun binary via `@rules_bun//bun:toolchain_type` (set
up by `register_toolchains("@bun//:bun_toolchain_def")` in your
MODULE.bazel).

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


