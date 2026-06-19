// Proof that `bun_test` resolves a dependency from the node_modules tree
// staged by `bun_deps.install` — NO aspect_rules_js, NO pnpm-lock.
//
// The import below ONLY resolves if the `node_modules` attr placed the
// `@install_npm//:node_modules` closure at the workspace runfiles root so Bun's
// resolver walks up into it. If staging is broken, the import throws at load
// time and the whole test file errors out (a hard failure, not a soft skip).
import { describe, expect, test } from "bun:test";
import isNumber from "is-number";

describe("bun_install node_modules resolution", () => {
  test("the is-number dep loads from the staged node_modules", () => {
    expect(typeof isNumber).toBe("function");
  });

  test("the dep behaves correctly", () => {
    expect(isNumber(42)).toBe(true);
    expect(isNumber("nope")).toBe(false);
  });
});
