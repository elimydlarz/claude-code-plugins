import { readFileSync } from "node:fs";
import { parseHookInput, planHook } from "./hook-plan.js";
import { gatherRepoState, executePlan } from "./hook-execute.js";
import { assertSafeSessionId, isUsableFilePath, reportInputError } from "./entry-input.js";
function main() {
    let rawInput = "";
    try {
        rawInput = readFileSync(0, "utf-8");
    }
    catch {
    }
    if (!rawInput.trim())
        process.exit(0);
    let input;
    try {
        input = parseHookInput(rawInput);
    }
    catch (error) {
        reportInputError(error);
    }
    try {
        if (input.session_id)
            assertSafeSessionId(input.session_id);
        if ((input.tool_name === "Edit" || input.tool_name === "Write") &&
            (input.tool_input.file_path === undefined || !isUsableFilePath(input.tool_input.file_path))) {
            throw new Error(`${input.tool_name} requires a usable file_path.`);
        }
    }
    catch (error) {
        reportInputError(error);
    }
    if (!input.tool_name)
        process.exit(0);
    const state = gatherRepoState(input);
    if (!state)
        process.exit(0);
    const plan = planHook(input, state);
    const result = executePlan(plan, input, state);
    if (result.stderr) {
        process.stderr.write(result.stderr + "\n");
    }
    process.exit(result.exitCode);
}
main();
