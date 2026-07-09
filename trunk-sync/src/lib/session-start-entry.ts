import { readFileSync } from "node:fs";
import { parseHookInput } from "./hook-plan.js";
import { gatherRepoState, getRuntimeContext, runSessionStart } from "./hook-execute.js";

function main(): void {
  let rawInput = "";
  try {
    rawInput = readFileSync(0, "utf-8");
  } catch {
    // no stdin
  }

  const input = parseHookInput(rawInput || "{}");
  const state = gatherRepoState(input);

  // Not in a git repo — no-op
  if (!state) process.exit(0);

  const message = runSessionStart(state, input.session_id, getRuntimeContext());
  if (message) process.stdout.write(message + "\n");
  process.exit(0);
}

main();
