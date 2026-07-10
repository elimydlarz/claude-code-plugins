import { readFileSync } from "node:fs";
import { classifyCommand } from "./command-guard.js";
function main() {
    const input = JSON.parse(readFileSync(0, "utf-8"));
    const value = input.tool_input?.command ?? "";
    const command = Array.isArray(value) ? value.join(" ") : value;
    const decision = classifyCommand(command);
    if (decision.exitCode === 2)
        process.stderr.write(`${decision.stderr}\n`);
    process.exit(decision.exitCode);
}
main();
