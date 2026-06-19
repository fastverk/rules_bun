#!/usr/bin/env bash
# Native `bun build` driver for bun_bundle / bun_compile — the Bun-native path
# that does NOT use an aspect_rules_js js_binary driver.
#
# Runs as a plain Bazel action (cwd = execroot). Bazel stages the entry + local
# srcs as SYMLINKS into the read-only source tree; `bun build` resolves an
# entry's realpath and then looks for `node_modules` next to that REAL file —
# which lives in the workspace, where there is no node_modules. So we instead
# materialize a real staging tree: copy each src (dereferencing the symlink) to
# its workspace-relative path under a private staging dir, drop the staged
# `node_modules` closure at the staging root, and run `bun build` from there.
# Bun then walks up from the (real) entry into the (real) node_modules.
#
# Inputs (positional):
#   $1  BUN        execroot-relative path to the toolchain bun binary
#   $2  ENTRY      workspace-relative path to the build entry
#   $3  OUT        execroot-relative output path
#   $4  NM_DIR     execroot-relative path to the dir CONTAINING node_modules
#                  (empty string = no node_modules to stage)
#   $5  MODE       "bundle" or "compile"
#   $6  FORMAT     bun --format (bundle mode only; ignored under compile)
#   $7  TARGET     bun --target (bundle: node|browser|bun; compile: triple/empty)
#   $8  SRCS_LIST  newline-separated workspace-relative src paths (the entry +
#                  any local modules); may be empty
#   shift 8; "$@"  zero or more `--external <name>` pairs
set -euo pipefail

BUN="$1"; ENTRY="$2"; OUT="$3"; NM_DIR="$4"; MODE="$5"; FORMAT="$6"; TARGET="$7"; SRCS_LIST="$8"
shift 8

export NO_COLOR=1
export DO_NOT_TRACK=1
export BUN_INSTALL_NO_TRACK=1

EXECROOT="$PWD"
ABS_BUN="$EXECROOT/$BUN"
ABS_OUT="$EXECROOT/$OUT"

# A real (non-symlink) staging tree so Bun's realpath-based resolver stays inside
# it instead of escaping to the workspace source dir.
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/bun_build.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

# Copy each src to STAGE preserving its workspace-relative path. -L dereferences
# the Bazel input symlink so the copy is a real file.
if [[ -n "$SRCS_LIST" ]]; then
  while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    mkdir -p "$STAGE/$(dirname "$src")"
    cp -L "$src" "$STAGE/$src"
  done <<< "$SRCS_LIST"
fi

# Drop the node_modules closure at the staging root. Symlink to the real closure
# (read-only inputs) so we don't duplicate a large tree.
if [[ -n "$NM_DIR" && -d "$EXECROOT/$NM_DIR/node_modules" ]]; then
  ln -s "$EXECROOT/$NM_DIR/node_modules" "$STAGE/node_modules"
fi

cd "$STAGE"

args=(build "./$ENTRY")
if [[ "$MODE" == "compile" ]]; then
  args+=(--compile)
  if [[ -n "$TARGET" ]]; then
    args+=(--target "$TARGET")
  fi
else
  args+=(--target "$TARGET" --format "$FORMAT")
fi
# Remaining argv is the already-formed `--external <name>` list.
args+=("$@")
args+=(--outfile "$ABS_OUT")

exec "$ABS_BUN" "${args[@]}"
