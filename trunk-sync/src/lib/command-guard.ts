export type CommandDecision =
  | { exitCode: 0 }
  | { exitCode: 2; stderr: string };

const GIT_GUIDANCE = "TRUNK-SYNC: Do NOT run write-side git commands. Read-only git inspection is allowed. Trunk-sync handles git writes; edit file contents instead.";

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

function gitInvocation(command: string): { subcommand: string; args: string[] } | null {
  const tokens = command.trim().split(/\s+/);
  if (tokens[0] !== "git") return null;
  if (tokens.length === 2 && tokens[1] === "--help") return { subcommand: "help", args: [] };
  if (tokens.length === 2 && tokens[1] === "--version") return { subcommand: "version", args: [] };

  let index = 1;
  while (index < tokens.length && tokens[index].startsWith("-")) {
    const option = tokens[index];
    index += 1;
    if (GLOBAL_OPTIONS_WITH_VALUES.has(option)) index += 1;
  }

  return { subcommand: tokens[index] ?? "", args: tokens.slice(index + 1) };
}

function isReadOnlyVariant(subcommand: string, args: string[]): boolean {
  if (READ_ONLY_COMMANDS.has(subcommand)) return true;
  if (subcommand === "clone") return true;

  if (subcommand === "branch") {
    if (args.length === 0) return true;
    const mutative = /^(?:-[dDmMcCftu]|--(?:copy|create-reflog|delete|edit-description|force|move|set-upstream-to|track|unset-upstream))(?:=|$)/;
    if (args.some((arg) => mutative.test(arg))) return false;
    return args.some((arg) => /^(?:-[arv]+|--(?:all|contains|format|ignore-case|list|merged|no-color|no-column|no-contains|no-merged|points-at|remotes|show-current|sort|verbose))(?:=|$)/.test(arg));
  }

  if (subcommand === "tag") {
    if (args.length === 0) return true;
    return args.some((arg) => /^(?:-l|--(?:contains|format|ignore-case|list|merged|no-contains|no-merged|points-at|sort))(?:=|$)/.test(arg));
  }

  if (subcommand === "remote") {
    return args.length === 0 || args.every((arg) => arg === "-v" || arg === "--verbose") || args[0] === "get-url" || args[0] === "show";
  }

  if (subcommand === "worktree") return args[0] === "list";
  if (subcommand === "stash") return args[0] === "list" || args[0] === "show";
  if (subcommand === "reflog") return args.length === 0 || args[0] === "show" || args[0] === "exists";
  if (subcommand === "config") {
    return args.some((arg) => /^(?:-l|--(?:get|get-all|get-regexp|get-urlmatch|list))(?:=|$)/.test(arg)) || args[0] === "get" || args[0] === "list";
  }

  return false;
}

function shellSegments(command: string): string[] {
  const segments: string[] = [];
  let start = 0;
  let quote = "";
  let escaped = false;

  for (let index = 0; index < command.length; index += 1) {
    const char = command[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char === "\\" && quote !== "'") {
      escaped = true;
      continue;
    }
    if (quote) {
      if (char === quote) quote = "";
      continue;
    }
    if (char === "'" || char === '"') {
      quote = char;
      continue;
    }
    if (char === ";" || char === "\n" || char === "|" || char === "&") {
      segments.push(command.slice(start, index));
      while (command[index + 1] === char) index += 1;
      start = index + 1;
    }
  }

  segments.push(command.slice(start));
  return segments;
}

export function classifyCommand(command: string): CommandDecision {
  const segments = shellSegments(command);
  if (!gitInvocation(segments[0])) return { exitCode: 0 };

  for (const segment of segments) {
    const invocation = gitInvocation(segment);
    if (invocation && !isReadOnlyVariant(invocation.subcommand, invocation.args)) {
      return { exitCode: 2, stderr: GIT_GUIDANCE };
    }
  }

  return { exitCode: 0 };
}
