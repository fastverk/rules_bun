#!/usr/bin/env bash
# Dev semantics (HMR, watch, on-demand module resolution) need to
# escape the runfiles sandbox, so we shell to the workspace's bun
# binary against the live source tree.
#
# Inputs (set by the bun_run macro via sh_binary env):
#   BUN_RUN_SCRIPT      — script name or path
#   BUN_RUN_EXTRA_ARGS  — extra args (space-separated)
set -euo pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  echo "error: must be invoked via 'bazel run'" >&2
  exit 1
fi

RUNFILES_DIR="${RUNFILES_DIR:-$0.runfiles}"
BUN_BIN="$(find "$RUNFILES_DIR" -name bun -type f -perm -u+x 2>/dev/null | head -1)"
if [[ -z "$BUN_BIN" ]]; then
  echo "error: cannot locate bun binary in runfiles" >&2
  exit 2
fi

# Telemetry/determinism pins (consistent with bun_test).
export NO_COLOR="${NO_COLOR:-1}"
export DO_NOT_TRACK="${DO_NOT_TRACK:-1}"
export BUN_INSTALL_NO_TRACK="${BUN_INSTALL_NO_TRACK:-1}"

cd "${BUILD_WORKSPACE_DIRECTORY}"
# shellcheck disable=SC2086
exec "$BUN_BIN" run "${BUN_RUN_SCRIPT:?BUN_RUN_SCRIPT env must be set by bun_run macro}" \
  ${BUN_RUN_EXTRA_ARGS} "$@"
