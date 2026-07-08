import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parseHookInput } from "./hook-plan.js";
import { gatherRepoState, runSessionStart } from "./hook-execute.js";

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

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

  const pluginRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
  const progressCommand = shellQuote(join(pluginRoot, "scripts", "trunk-sync-progress.sh"));
  const message = runSessionStart(state.repoRoot, input.session_id, progressCommand);
  if (message) process.stdout.write(message + "\n");
  process.exit(0);
}

main();
