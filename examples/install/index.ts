// Pure-Bun bun_bundle entry point.
//
// `is-number` is provided by the `@install_npm//:node_modules` closure that
// `bun_deps.install` staged with `bun install --frozen-lockfile` — NO
// aspect_rules_js, NO pnpm-lock. Bun's resolver finds it because the closure
// is symlinked at the execroot root and Bun walks up from this entry.
import isNumber from "is-number";

import { greet } from "./greet";

function main(): void {
  if (!isNumber(42) || isNumber("nope" as unknown as number)) {
    console.error("is-number resolved/bundled incorrectly");
    process.exit(1);
  }
  console.log(greet("rules_bun (bun_install)"));
}

main();
