export type CommandDecision =
  | { exitCode: 0 }
  | { exitCode: 2; stderr: string };

const GIT_GUIDANCE = "TRUNK-SYNC: Do NOT run write-side git commands. Read-only git inspection is allowed. Trunk-sync handles git writes; edit file contents instead.";
const COMPOSED_GIT_GUIDANCE = "TRUNK-SYNC: Run standalone Git inspection without shell composition. Trunk-sync rejects Git invocations composed with other shell commands.";

const READ_ONLY_COMMANDS = new Set([
  "annotate",
  "blame",
  "cat-file",
  "cherry",
  "count-objects",
  "describe",
  "diff",
  "diff-files",
  "diff-index",
  "diff-tree",
  "for-each-ref",
  "grep",
  "help",
  "log",
  "ls-files",
  "ls-remote",
  "ls-tree",
  "merge-base",
  "name-rev",
  "range-diff",
  "rev-list",
  "rev-parse",
  "shortlog",
  "show",
  "show-branch",
  "show-index",
  "show-ref",
  "status",
  "verify-commit",
  "verify-pack",
  "verify-tag",
  "version",
  "whatchanged",
]);

const GLOBAL_OPTIONS_WITH_VALUES = new Set([
  "-C",
  "-c",
  "--config-env",
  "--git-dir",
  "--namespace",
  "--super-prefix",
  "--work-tree",
]);

function directGitInvocation(command: string): { subcommand: string; args: string[] } {
  const tokens = command.split(/\s+/);
  if (tokens.length === 2 && tokens[1] === "--help") return { subcommand: "help", args: [] };
  if (tokens.length === 2 && tokens[1] === "--version") return { subcommand: "version", args: [] };

  let index = 1;
  while (index < tokens.length && tokens[index].startsWith("-")) {
    const option = tokens[index];
    index += 1;
    if (GLOBAL_OPTIONS_WITH_VALUES.has(option)) index += 1;
  }

  return {
    subcommand: tokens[index] ?? "",
    args: tokens.slice(index + 1),
  };
}

function startsExecutableGit(command: string): boolean {
  const value = command.trim().replace(/^(?:!\s+)+/, "");
  return /^(?:\S*\/)?git(?:\s|$)/.test(value)
    || /^command(?:\s+-\S+)*\s+(?:\S*\/)?git(?:\s|$)/.test(value)
    || /^(?:sudo|exec|nice|nohup|time)(?:\s+-\S+)*\s+(?:\S*\/)?git(?:\s|$)/.test(value)
    || /^env(?:\s+(?:-\S+|[A-Za-z_][A-Za-z0-9_]*=\S*))*\s+(?:\S*\/)?git(?:\s|$)/.test(value)
    || /^(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)+(?:\S*\/)?git(?:\s|$)/.test(value);
}

function withoutQuotedOrEscapedText(command: string): string {
  return command
    .replace(/\\([A-Za-z0-9_])/g, "$1")
    .replace(/\\./g, "")
    .replace(/'(?:[^']*)'|"(?:[^"]*)"/g, "");
}

function normalizeQuotedGitExecutable(command: string): string {
  const match = command.trim().match(/^(\S+)([\s\S]*)$/);
  if (!match) return command.trim();
  const executable = match[1]
    .replace(/\$?'([^']*)'/g, "$1")
    .replace(/"([^"]*)"/g, "$1");
  return executable === "git" ? `git${match[2]}` : command.trim();
}

function executableShellText(command: string): string {
  return command.replace(/\\./g, "").replace(/'(?:[^']*)'/g, "");
}

function containsGitSubstitution(command: string): boolean {
  const substitutions = [...executableShellText(command).matchAll(/\$\(([^)]*)\)|`([^`]*)`/g)];
  return substitutions.some((match) => {
    const inner = withoutQuotedOrEscapedText(match[1] ?? match[2] ?? "");
    return inner.split(/[;&|()<>\n]+/).some(startsExecutableGit);
  });
}

function containsExecutableSubstitution(command: string): boolean {
  const executableText = executableShellText(command);
  return executableText.includes("`") || executableText.includes("$(");
}

function shellCommandSegments(command: string): string[] {
  return command.match(/(?:\\.|'(?:[^']*)'|"(?:[^"]*)"|[^;&|()\n])+/g) ?? [];
}

function containsCommandPositionParameterExpansion(command: string): boolean {
  return shellCommandSegments(command).some((segment) => {
    const executable = segment.trimStart().replace(
      /^(?:(?:[A-Za-z_][A-Za-z0-9_]*=\S+)\s+)*(?:(?:command|exec|sudo|nice|nohup|time)(?:\s+-\S+)*\s+)*/,
      "",
    );
    return /^(?:"\$(?:[A-Za-z_][A-Za-z0-9_]*|\{[^}\n]+\})"|\$(?:[A-Za-z_][A-Za-z0-9_]*|\{[^}\n]+\}))(?:\/|\s|$)/.test(executable)
      || /^[A-Za-z0-9_./-]*\$(?:[A-Za-z_][A-Za-z0-9_]*|\{[^}\n]+\})[A-Za-z0-9_./-]*(?:\s|$)/.test(executable);
  });
}

function containsDangerousIndirection(command: string, visible: string, direct: boolean): boolean {
  const shellCommand = visible.split(/[;&|()<>\n]+/).some((segment) => /^\s*(?:(?:[A-Za-z_][A-Za-z0-9_]*=\S*)\s+)*(?:(?:(?:command|exec|sudo|nice|nohup|time)(?:\s+-\S+)*|(?:\S*\/)?env(?:\s+(?:-\S+|[A-Za-z_][A-Za-z0-9_]*=\S*))*)\s+)*(?:\S*\/)?(?:ba|z|da|k)?sh(?:\s+-(?![A-Za-z]*c[A-Za-z]*(?:\s|$))\S+)*\s+-[A-Za-z]*c[A-Za-z]*(?:\s|$)/.test(segment));
  const evalCommand = visible.split(/[;&|()<>\n]+/).some((segment) => /^\s*(?:(?:command|builtin)\s+)?eval(?:\s|$)/.test(segment));
  const commandPositionExpansion = /^\s*(?:(?:[A-Za-z_][A-Za-z0-9_]*=\S*)\s+)*(?:(?:(?:command|exec|sudo|nice|nohup|time)(?:\s+-\S+)*|env(?:\s+(?:-\S+|[A-Za-z_][A-Za-z0-9_]*=\S*))*)\s+)*\S*(?:\$\(|`)/.test(command);
  const executableSubstitution = containsExecutableSubstitution(command);
  const decodedEscapes = command.replace(/\\([A-Za-z0-9_])/g, "$1");
  return shellCommand && /\bgit\b/.test(decodedEscapes)
    || evalCommand && /\bgit\b/.test(decodedEscapes)
    || commandPositionExpansion
    || direct && executableSubstitution;
}

function isReadOnlyVariant(subcommand: string, args: string[]): boolean {
  if (args.some((arg) => /^(?:--ext-diff|--output(?:=.*)?|--textconv)$/.test(arg))) return false;
  if (READ_ONLY_COMMANDS.has(subcommand)) return true;
  if (subcommand === "clone") return true;

  if (subcommand === "branch") {
    if (args.length === 0) return true;
    const mutative = /^(?:-[dDmMcCftu]|--(?:copy|create-reflog|delete|edit-description|force|move|set-upstream-to|track|unset-upstream))(?:=|$)/;
    if (args.some((arg) => mutative.test(arg))) return false;
    return args.some((arg) => /^(?:-[arv]+|--(?:all|column|contains|format|ignore-case|list|merged|no-color|no-column|no-contains|no-merged|points-at|remotes|show-current|sort|verbose))(?:=|$)/.test(arg));
  }

  if (subcommand === "tag") {
    if (args.length === 0) return true;
    return args.some((arg) => /^(?:-l|-n\d*|--(?:contains|format|ignore-case|list|merged|no-contains|no-merged|points-at|sort))(?:=|$)/.test(arg));
  }

  if (subcommand === "remote") {
    return args.every((arg) => arg === "-v" || arg === "--verbose") || args[0] === "get-url" || args[0] === "show";
  }

  if (subcommand === "config") {
    return args.some((arg) => /^(?:-l|--(?:get|get-all|get-regexp|get-urlmatch|list))(?:=|$)/.test(arg)) || args[0] === "get" || args[0] === "list";
  }
  if (subcommand === "worktree") return args[0] === "list";
  if (subcommand === "stash") return args[0] === "list" || args[0] === "show";
  if (subcommand === "reflog") return args.length === 0 || args[0] === "show" || args[0] === "exists";

  return false;
}

export function classifyCommand(command: string): CommandDecision {
  const trimmed = normalizeQuotedGitExecutable(command);
  const visible = withoutQuotedOrEscapedText(trimmed);
  const commandSegments = visible.split(/[;&|()\n`]+/);
  const compositionSegments = visible.split(/[;&|()<>\n`]+/);
  const direct = /^git(?:\s|$)/.test(trimmed);
  if (containsGitSubstitution(trimmed)
    || containsDangerousIndirection(trimmed, visible, direct)
    || containsCommandPositionParameterExpansion(trimmed)) {
    return { exitCode: 2, stderr: COMPOSED_GIT_GUIDANCE };
  }
  if (!direct) {
    return commandSegments.some(startsExecutableGit)
      ? { exitCode: 2, stderr: COMPOSED_GIT_GUIDANCE }
      : { exitCode: 0 };
  }
  if (compositionSegments.length > 1) {
    return { exitCode: 2, stderr: COMPOSED_GIT_GUIDANCE };
  }

  const invocation = directGitInvocation(trimmed);
  if (!isReadOnlyVariant(invocation.subcommand, invocation.args)) {
    return { exitCode: 2, stderr: GIT_GUIDANCE };
  }

  return { exitCode: 0 };
}
