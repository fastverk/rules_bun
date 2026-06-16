#!/usr/bin/env node
/**
 * Shared driver for `bun_bundle` and `bun_compile`.
 *
 * Run as the entry point of an aspect_rules_js `js_binary`, so aspect's
 * launcher materializes the full linked `node_modules` closure (plus the build
 * entry) into this process's runfiles before we start. We then shell out to the
 * hermetic Bun binary to either bundle the entry into one self-contained JS file
 * (`bun build`) or compile it into a standalone native executable
 * (`bun build --compile`).
 *
 * The aspect launcher exports the execroot (`JS_BINARY__EXECROOT`) and the
 * runfiles root (`JS_BINARY__RUNFILES`) but, with `BAZEL_BINDIR="."`, does NOT
 * chdir into the runfiles tree. `--bun` and `--out` are passed execroot-relative
 * and re-anchored here on the execroot (absolute, so they survive the chdir
 * below). `--entry` is relative to the workspace (`_main`) runfiles root, where
 * the linked node_modules closure lives — so we chdir there and let Bun's
 * resolver walk that staged tree (no `bun install` required).
 *
 * Args:
 *   --bun <path>        execroot-relative path to the Bun binary (toolchain)
 *   --entry <path>      entry point relative to the `_main` runfiles root
 *                       (e.g. packages/aion-cli/index.js)
 *   --out <path>        execroot-relative output path (bundle file, or the
 *                       standalone executable under --compile)
 *   --format <fmt>      Bun --format (esm|cjs|iife). Ignored under --compile.
 *   --target <triple>   Bun --target. For a bundle: node|browser|bun. For a
 *                       compile: a Bun compile target triple (bun-linux-x64,
 *                       bun-darwin-arm64, …) or empty for the host default.
 *   --external <name>   exclude a module from the bundle (repeatable)
 *   --compile           emit a standalone native executable instead of a bundle
 */
import { spawnSync } from "node:child_process";
import path from "node:path";

function arg(name) {
  const i = process.argv.indexOf(name);
  if (i === -1 || i + 1 >= process.argv.length) {
    throw new Error(`bun build driver: missing required arg ${name}`);
  }
  return process.argv[i + 1];
}

// Repeatable: collect every `--name <value>` pair from argv.
function argAll(name) {
  const out = [];
  for (let i = 0; i < process.argv.length - 1; i++) {
    if (process.argv[i] === name) {
      out.push(process.argv[i + 1]);
    }
  }
  return out;
}

function hasFlag(name) {
  return process.argv.includes(name);
}

const execroot = process.env.JS_BINARY__EXECROOT;
const runfiles = process.env.JS_BINARY__RUNFILES;
if (!execroot || !runfiles) {
  console.error(
    "bun build driver: JS_BINARY__EXECROOT / JS_BINARY__RUNFILES not set",
  );
  process.exit(1);
}

const bun = path.join(execroot, arg("--bun"));
const entry = arg("--entry");
const out = path.join(execroot, arg("--out"));
const format = arg("--format");
const target = arg("--target");
const externals = argAll("--external");
const compile = hasFlag("--compile");

// CWD into the workspace runfiles root so the linked node_modules sits next to
// the entry for Bun's resolver.
process.chdir(path.join(runfiles, "_main"));

const buildArgs = ["build", `./${entry}`];
if (compile) {
  // Standalone executable: Bun runtime + bundled JS in one file. `--target`
  // selects the Bun compile target triple; empty means the host platform.
  buildArgs.push("--compile");
  if (target) {
    buildArgs.push("--target", target);
  }
} else {
  // Single-file bundle. `--target` selects the JS execution environment and
  // defaults to "node" upstream of here, so it is always set.
  buildArgs.push("--target", target, "--format", format);
}
for (const ext of externals) {
  buildArgs.push("--external", ext);
}
buildArgs.push("--outfile", out);

const result = spawnSync(bun, buildArgs, {
  stdio: "inherit",
  env: {
    ...process.env,
    NO_COLOR: "1",
    DO_NOT_TRACK: "1",
    BUN_INSTALL_NO_TRACK: "1",
  },
});

if (result.error) {
  console.error(`bun build driver: failed to spawn bun: ${result.error.message}`);
  process.exit(1);
}
process.exit(result.status ?? 1);
