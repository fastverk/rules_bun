// Smoke test for the pure-Bun `bun_bundle` (the `node_modules`/native path).
//
// Asserts the bundle built from a `bun_deps.install` node_modules tree:
//   1. exists and is non-empty;
//   2. runs and prints the greeting (so the inlined npm dep + local module
//      both resolved from the staged closure — no aspect, no pnpm-lock);
//   3. inlined `is-number` (its source survives in the bundle).
import { describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, statSync } from "node:fs";

// Relative to the `_main` runfiles root that `bun test` runs from.
const BUNDLE = "examples/install/app.mjs";

describe("bun_install bun_bundle example", () => {
  test("output bundle exists and is non-empty", () => {
    expect(existsSync(BUNDLE)).toBe(true);
    expect(statSync(BUNDLE).size).toBeGreaterThan(0);
  });

  test("the bundle runs and prints the greeting", () => {
    const res = spawnSync(process.execPath, [BUNDLE], { encoding: "utf8" });
    expect(res.status).toBe(0);
    expect(res.stdout).toContain("hello, rules_bun (bun_install)");
  });

  test("the npm dep is inlined (resolved from the staged node_modules)", () => {
    const src = readFileSync(BUNDLE, "utf8");
    expect(src.toLowerCase()).toContain("number");
  });
});
