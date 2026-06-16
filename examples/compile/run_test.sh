#!/usr/bin/env bash
# Smoke test for the host `bun_compile` example: the produced file must be an
# executable that runs and prints the expected output.
set -euo pipefail

BIN="${1:?usage: run_test.sh <path-to-compiled-binary>}"

if [[ ! -x "$BIN" ]]; then
  echo "FAIL: $BIN is not executable" >&2
  exit 1
fi

out="$("$BIN" --version)"
echo "binary output: $out"

case "$out" in
  *"rules_bun-compile-example"*) ;;
  *)
    echo "FAIL: unexpected output from compiled binary: $out" >&2
    exit 1
    ;;
esac

echo "PASS: compiled binary is executable and runs"
