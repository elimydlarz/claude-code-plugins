import { readFileSync } from "node:fs";
import { parseHookInput } from "./hook-plan.js";
import { gatherRepoState, runStop } from "./hook-execute.js";
import { reportInputError } from "./entry-input.js";
function main() {
    let rawInput = "";
    try {
        rawInput = readFileSync(0, "utf-8");
    }
    catch {
    }
    let input;
    try {
        input = parseHookInput(rawInput || "{}");
    }
    catch (error) {
        reportInputError(error);
    }
    if (input.cwd) {
        try {
            process.chdir(input.cwd);
        }
        catch (error) {
            reportInputError(error);
        }
    }
    const state = gatherRepoState(input);
    if (!state)
        process.exit(0);
    let result;
    try {
        result = runStop(state, input.session_id);
    }
    catch (error) {
        reportInputError(error);
    }
    const { warning } = result;
    if (warning)
        process.stderr.write(warning + "\n");
    process.exit(0);
}
main();
