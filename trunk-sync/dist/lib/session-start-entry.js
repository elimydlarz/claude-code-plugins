import { readFileSync } from "node:fs";
import { parseHookInput } from "./hook-plan.js";
import { gatherRepoState, runSessionStart } from "./hook-execute.js";
function main() {
    let rawInput = "";
    try {
        rawInput = readFileSync(0, "utf-8");
    }
    catch {
        // no stdin
    }
    const input = parseHookInput(rawInput || "{}");
    const state = gatherRepoState(input);
    // Not in a git repo — no-op
    if (!state)
        process.exit(0);
    const message = runSessionStart(state.repoRoot, input.session_id);
    if (message)
        process.stdout.write(message + "\n");
    process.exit(0);
}
main();
