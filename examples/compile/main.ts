// bun_compile entry point.
//
// Compiled by `bun build --compile` into a standalone native executable for the
// host platform (Bun runtime + this bundled JS in one file). It imports a pure
// npm dep so the example also exercises node_modules resolution under compile.
import isNumber from "is-number";

const arg = process.argv[2];

if (arg === "--version") {
  console.log("rules_bun-compile-example 0.4.0");
  process.exit(0);
}

console.log(isNumber(7) ? "compiled ok" : "compiled wrong");
