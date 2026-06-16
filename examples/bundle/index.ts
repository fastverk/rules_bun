// bun_bundle entry point.
//
//   * `is-number` — a tiny pure npm dep, bundled inline.
//   * `./greet`   — a local module, bundled inline.
//   * `source-map-support` — marked `external` in the BUILD, so `bun build`
//     keeps it as a runtime `require`/`import` instead of inlining its source.
//     It is referenced only on a branch that never runs here, so the bundle
//     executes standalone; a consumer that did exercise it would provide the
//     package at runtime (next to the bundle).
import isNumber from "is-number";

import { greet } from "./greet";

function main(): void {
  if (!isNumber(42) || isNumber("nope" as unknown as number)) {
    console.error("is-number bundled incorrectly");
    process.exit(1);
  }

  // Reference the external without executing it, so the bundle stays runnable
  // while still emitting an un-inlined import for `source-map-support`.
  if (process.env.RULES_BUN_INSTALL_SOURCE_MAPS === "1") {
    const sms = require("source-map-support");
    sms.install();
  }

  console.log(greet("rules_bun"));
}

main();
