import { readFileSync } from "node:fs";
import { parseHookInput } from "./hook-plan.js";
import { gatherRepoState, getRuntimeContext, runSessionStart } from "./hook-execute.js";
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
        result = runSessionStart(state, input.session_id, getRuntimeContext());
    }
    catch (error) {
        reportInputError(error);
    }
    const { message, warning } = result;
    if (message)
        process.stdout.write(message + "\n");
    if (warning)
        process.stderr.write(warning + "\n");
    process.exit(0);
}
main();
