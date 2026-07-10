export type CommandDecision =
  | { exitCode: 0 }
  | { exitCode: 2; stderr: string };

const GIT_GUIDANCE = "TRUNK-SYNC: Do NOT run git commands. The trunk-sync hook handles all git operations. Your only job is to fix file contents using Edit.";

export function classifyCommand(command: string): CommandDecision {
  if (command === "git" || command.startsWith("git ")) {
    return { exitCode: 2, stderr: GIT_GUIDANCE };
  }
  return { exitCode: 0 };
}
