import { readFileSync } from "node:fs";
import { classifyCommand } from "./command-guard.js";

interface PreToolInput {
  tool_input?: {
    command?: string | string[];
  };
}

function main(): void {
  const input = JSON.parse(readFileSync(0, "utf-8")) as PreToolInput;
  const value = input.tool_input?.command ?? "";
  const command = Array.isArray(value) ? value.join(" ") : value;
  const decision = classifyCommand(command);
  if (decision.exitCode === 2) process.stderr.write(`${decision.stderr}\n`);
  process.exit(decision.exitCode);
}

main();
