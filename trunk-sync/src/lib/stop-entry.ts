import { readFileSync } from "node:fs";
import { parseHookInput } from "./hook-plan.js";
import { gatherRepoState, runStop } from "./hook-execute.js";

function main(): void {
  let rawInput = "";
  try {
    rawInput = readFileSync(0, "utf-8");
  } catch {
    // no stdin
  }

  const input = parseHookInput(rawInput || "{}");
  if (input.cwd) {
    try {
      process.chdir(input.cwd);
    } catch {
      process.exit(0);
    }
  }
  const state = gatherRepoState(input);

  // Not in a git repo — no-op
  if (!state) process.exit(0);

  runStop(state, input.session_id);
  process.exit(0);
}

main();
