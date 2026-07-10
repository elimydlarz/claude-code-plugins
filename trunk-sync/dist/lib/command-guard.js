const GIT_GUIDANCE = "TRUNK-SYNC: Do NOT run git commands. The trunk-sync hook handles all git operations. Your only job is to fix file contents using Edit.";
export function classifyCommand(command) {
    if (/^git (?:-C .+ )?(?:clone|diff|log|show)(?: |$)/.test(command)) {
        return { exitCode: 0 };
    }
    if (command === "git" || command.startsWith("git ")) {
        return { exitCode: 2, stderr: GIT_GUIDANCE };
    }
    return { exitCode: 0 };
}
