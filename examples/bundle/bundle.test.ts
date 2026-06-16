// Smoke test for the `bun_bundle` example.
//
// Asserts the three bundling contracts:
//   1. the output bundle file exists and is non-empty;
//   2. running it under a JS runtime prints the expected greeting (so the
//      inlined npm dep + local module work);
//   3. the `external` (`source-map-support`) is NOT inlined — the bundle keeps
//      an un-inlined import/require of it instead of its source body.
import { describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, statSync } from "node:fs";

// Path is relative to the `_main` runfiles root that `bun test` runs from.
const BUNDLE = "examples/bundle/app.mjs";

describe("bun_bundle example", () => {
  test("output bundle exists and is non-empty", () => {
    expect(existsSync(BUNDLE)).toBe(true);
    expect(statSync(BUNDLE).size).toBeGreaterThan(0);
  });

  test("the bundle runs and prints the greeting", () => {
    const res = spawnSync(process.execPath, [BUNDLE], { encoding: "utf8" });
    expect(res.status).toBe(0);
    expect(res.stdout).toContain("hello, rules_bun");
  });

  test("the npm dep and local module are inlined", () => {
    const src = readFileSync(BUNDLE, "utf8");
    // is-number's guard text + the local greet template both survive inlining.
    expect(src).toContain("hello, ");
    expect(src.toLowerCase()).toContain("number");
  });

  test("the external is NOT inlined", () => {
    const src = readFileSync(BUNDLE, "utf8");
    // source-map-support is referenced (as an external import/require)…
    expect(src).toContain("source-map-support");
    // …but its source body (which defines this function) must NOT be present.
    expect(src).not.toContain("function getErrorSource");
  });
});
