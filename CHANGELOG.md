# Changelog

All notable changes to rules_bun. The format is loosely
[Keep a Changelog](https://keepachangelog.com/) — version headers
mirror the published bazel-registry entries.

## 0.2.1 — fix bun_test toolchain runfiles path under bzlmod

- `bun_test`'s generated runner failed to locate the hermetic Bun binary
  under bzlmod, exiting 127 (`exec: : not found`). Under bzlmod the
  toolchain Bun is an external repo file whose `short_path` is
  `../rules_bun++bun+bun/bun`; the runner built `BUN_BIN` as
  `${RUNFILES_DIR}/<short_path>`, so the leading `../` escaped the
  runfiles tree. Prefix with `_main/` (`${RUNFILES_DIR}/_main/<short_path>`)
  so the embedded `../` resolves back out to the sibling external repo.
- Make the `find` fallback follow symlinks (`find -L`) so it can reach
  the symlinked Bun binary in the runfiles tree.
- Resolve the `srcs` test-filter paths from the same `${RUNFILES_DIR}`
  base as `BUN_BIN` (was `$0.runfiles`). Under `bazel test` Bazel sets
  `RUNFILES_DIR` and `$0` is the already-staged in-runfiles script, so
  `$0.runfiles` double-appended `.runfiles/_main`, yielding a test
  filter with no matches.

## 0.2.0 — delegate release fetching to rules_github

- Replace the in-tree GitHub release download logic with a dependency
  on `rules_github`'s `github_binary_repository` so Bun binaries are
  fetched via the shared substrate alongside other fastverk rules.

## 0.1.0 — initial release

- First cut of Bazel rules for [Bun](https://bun.sh/): a `bun` module
  extension that auto-creates `@bun` with the host-platform binary, a
  `bun_toolchain` resolved via `@rules_bun//bun:toolchain_type`, plus
  `bun_test` (hermetic) and `bun_run` (sandbox-escaping) rules.
