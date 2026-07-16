import { readFileSync } from "node:fs";
import { classifyCommand } from "./command-guard.js";
import { isInputObject, parseInputObject, reportInputError } from "./entry-input.js";
function main() {
    let command = "";
    try {
        const input = parseInputObject(readFileSync(0, "utf-8"));
        const toolInput = input.tool_input ?? {};
        if (!isInputObject(toolInput))
            throw new Error("tool_input must be a JSON object.");
        const value = toolInput.command ?? "";
        if (typeof value === "string")
            command = value;
        else if (Array.isArray(value) && value.every((part) => typeof part === "string"))
            command = value.join(" ");
        else
            throw new Error("command must be a string or string array when provided.");
    }
    catch (error) {
        reportInputError(error);
    }
    const decision = classifyCommand(command);
    if (decision.exitCode === 2)
        process.stderr.write(`${decision.stderr}\n`);
    process.exit(decision.exitCode);
}
main();
