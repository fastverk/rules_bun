# Changelog

All notable changes to rules_bun. The format is loosely
[Keep a Changelog](https://keepachangelog.com/) — version headers
mirror the published bazel-registry entries.

## 0.2.0 — delegate release fetching to rules_github

- Replace the in-tree GitHub release download logic with a dependency
  on `rules_github`'s `github_binary_repository` so Bun binaries are
  fetched via the shared substrate alongside other fastverk rules.

## 0.1.0 — initial release

- First cut of Bazel rules for [Bun](https://bun.sh/): a `bun` module
  extension that auto-creates `@bun` with the host-platform binary, a
  `bun_toolchain` resolved via `@rules_bun//bun:toolchain_type`, plus
  `bun_test` (hermetic) and `bun_run` (sandbox-escaping) rules.
