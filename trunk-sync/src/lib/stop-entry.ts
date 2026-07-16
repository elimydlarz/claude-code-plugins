import { readFileSync } from "node:fs";
import { parseHookInput } from "./hook-plan.js";
import { gatherRepoState, runStop } from "./hook-execute.js";
import { reportInputError } from "./entry-input.js";
import type { HookInput } from "./hook-types.js";

function main(): void {
  let rawInput = "";
  try {
    rawInput = readFileSync(0, "utf-8");
  } catch {
  }

  let input: HookInput;
  try {
    input = parseHookInput(rawInput || "{}");
  } catch (error: unknown) {
    reportInputError(error);
  }
  if (input.cwd) {
    try {
      process.chdir(input.cwd);
    } catch (error: unknown) {
      reportInputError(error);
    }
  }
  const state = gatherRepoState(input);

  if (!state) process.exit(0);

  let result: ReturnType<typeof runStop>;
  try {
    result = runStop(state, input.session_id);
  } catch (error: unknown) {
    reportInputError(error);
  }
  const { warning } = result;
  if (warning) process.stderr.write(warning + "\n");
  process.exit(0);
}

main();
