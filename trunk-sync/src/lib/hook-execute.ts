import { execSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, mkdirSync, writeFileSync, readdirSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { homedir, hostname } from "node:os";
import type { HookInput, RepoState, HookPlan, SyncPlan, Timecard, RuntimeContext } from "./hook-types.js";
import { HOOK_EXPLAINER } from "./hook-types.js";
import { extractTaskFromTranscript, buildCommitPlanWithTask, classifyTimecards, formatClockInMessage, formatSessionStartSummary } from "./hook-plan.js";

const DEFAULT_TARGET_BRANCH = "agents";

/**
 * Gather the current git repo state needed for planning.
 * Runs git commands — this is the I/O boundary.
 */
export function gatherRepoState(input: HookInput): RepoState | null {
  const filePath = input.tool_input.file_path ?? null;

  let repoRoot: string;
  let gitDir: string;
  try {
    const [toplevel, dir] = execSync("git rev-parse --show-toplevel --git-dir", { encoding: "utf-8" }).trim().split("\n");
    repoRoot = toplevel;
    gitDir = dir;
  } catch {
    return null; // not in a git repo
  }

  let insideRepo = true;
  let gitignored = false;
  let relPath: string | null = null;

  if (filePath) {
    // Resolve symlinks so /var/... matches /private/var/... on macOS
    const resolvedFile = existsSync(filePath) ? realpathSync(filePath) : filePath;
    insideRepo = resolvedFile.startsWith(repoRoot + "/");
    if (insideRepo) {
      relPath = resolvedFile.slice(repoRoot.length + 1);
      try {
        execSync(`git check-ignore -q -- "${filePath}"`, { stdio: "ignore" });
        gitignored = true;
      } catch {
        gitignored = false;
      }
    }
  }

  let hasRemote = false;
  try {
    execSync("git remote get-url origin", { stdio: "ignore" });
    hasRemote = true;
  } catch {
    // no remote
  }

  let targetBranch = "";
  if (hasRemote) {
    targetBranch = DEFAULT_TARGET_BRANCH;
  }

  let currentBranch = "";
  const headContent = readFileSync(join(gitDir, "HEAD"), "utf-8").trim();
  if (headContent.startsWith("ref: refs/heads/")) {
    currentBranch = headContent.slice("ref: refs/heads/".length);
  }

  const inMerge = existsSync(join(gitDir, "MERGE_HEAD"));

  let hasStagedChanges = false;
  try {
    execSync("git diff --cached --quiet", { stdio: "ignore" });
  } catch {
    hasStagedChanges = true;
  }

  let deletedFiles: string[] = [];
  let modifiedFiles: string[] = [];
  let untrackedFiles: string[] = [];
  if (!filePath) {
    try {
      const deleted = execSync(`git -C "${repoRoot}" ls-files --deleted`, {
        encoding: "utf-8",
      }).trim();
      if (deleted) deletedFiles = deleted.split("\n");
    } catch {
      // ignore
    }
    try {
      const modified = execSync(`git -C "${repoRoot}" diff --name-only`, {
        encoding: "utf-8",
      }).trim();
      if (modified) {
        // Exclude files already in deletedFiles (diff --name-only includes deletions)
        const deletedSet = new Set(deletedFiles);
        modifiedFiles = modified.split("\n").filter((f) => !deletedSet.has(f));
      }
    } catch {
      // ignore
    }
    try {
      const untracked = execSync(
        `git -C "${repoRoot}" ls-files --others --exclude-standard`,
        { encoding: "utf-8" },
      ).trim();
      if (untracked) untrackedFiles = untracked.split("\n");
    } catch {
      // ignore
    }
  }

  return {
    repoRoot,
    gitDir,
    relPath,
    insideRepo,
    gitignored,
    hasRemote,
    targetBranch,
    currentBranch,
    inMerge,
    hasStagedChanges,
    deletedFiles,
    modifiedFiles,
    untrackedFiles,
  };
}

export function getRuntimeContext(): RuntimeContext {
  return { hostname: hostname() };
}

export function clockIn(repoRoot: string, timecard: Timecard): void {
  const dir = join(repoRoot, ".trunk-sync", "timeclock");
  mkdirSync(dir, { recursive: true });
  const filePath = join(dir, `${timecard.sessionId}.json`);
  let nextTimecard = { ...timecard };
  try {
    const existing = JSON.parse(readFileSync(filePath, "utf-8")) as Timecard;
    if (existing.clockedInAt) {
      nextTimecard = { ...nextTimecard, clockedInAt: existing.clockedInAt };
    }
  } catch {
  }
  writeFileSync(filePath, JSON.stringify(nextTimecard, null, 2) + "\n");
}

export function readTimecards(repoRoot: string): Timecard[] {
  const dir = join(repoRoot, ".trunk-sync", "timeclock");
  if (!existsSync(dir)) return [];
  const files = readdirSync(dir).filter((f) => f.endsWith(".json"));
  const timecards: Timecard[] = [];
  for (const file of files) {
    try {
      const content = readFileSync(join(dir, file), "utf-8");
      timecards.push(JSON.parse(content) as Timecard);
    } catch {
    }
  }
  return timecards;
}

export function runSessionStart(state: RepoState, ownSessionId: string | null, runtime: RuntimeContext): string | null {
  if (!ownSessionId) return null;
  clockIn(state.repoRoot, buildTimecard(ownSessionId, state, runtime));
  commitTimecardChange(state, `auto: clock-in ${ownSessionId.slice(0, 8)}`);
  syncBestEffort(state);

  const intro = `TRUNK-SYNC SESSION: your session id is ${ownSessionId}.`;
  const now = new Date();
  const { active } = classifyTimecards(ownSessionId, readTimecards(state.repoRoot), now);
  const roster = formatSessionStartSummary(active, now);
  return roster ? `${intro}\n\n${roster}` : intro;
}

export function runStop(state: RepoState, sessionId: string | null): void {
  if (!sessionId) return;
  const cardPath = join(state.repoRoot, ".trunk-sync", "timeclock", `${sessionId}.json`);
  try {
    unlinkSync(cardPath);
  } catch {
    return;
  }

  commitTimecardChange(state, `auto: clock-out ${sessionId.slice(0, 8)}`);
  syncBestEffort(state);
}

export function reapCards(repoRoot: string, ids: string[]): string[] {
  const removed: string[] = [];
  for (const id of ids) {
    const filePath = join(repoRoot, ".trunk-sync", "timeclock", `${id}.json`);
    try {
      unlinkSync(filePath);
      removed.push(filePath);
    } catch {
    }
  }
  return removed;
}

function buildTimecard(sessionId: string, state: RepoState, runtime: RuntimeContext): Timecard {
  const now = new Date().toISOString();
  return {
    sessionId,
    hostname: runtime.hostname,
    clockedInAt: now,
    lastActiveAt: now,
    branch: state.currentBranch || "detached",
  };
}

function touchTimecard(state: RepoState, sessionId: string | null): void {
  if (!sessionId) return;
  const cardPath = join(state.repoRoot, ".trunk-sync", "timeclock", `${sessionId}.json`);
  let card: Timecard;
  try {
    card = JSON.parse(readFileSync(cardPath, "utf-8")) as Timecard;
  } catch {
    return;
  }

  card.lastActiveAt = new Date().toISOString();
  card.branch = state.currentBranch || "detached";
  writeFileSync(cardPath, JSON.stringify(card, null, 2) + "\n");
  execSync(`git -C "${state.repoRoot}" add -- ".trunk-sync/timeclock/${sessionId}.json"`, { stdio: "ignore" });
}

function reapOldTimecards(state: RepoState, ownSessionId: string | null): void {
  const { reapable } = classifyTimecards(ownSessionId, readTimecards(state.repoRoot), new Date());
  if (reapable.length === 0) return;
  reapCards(state.repoRoot, reapable.map((tc) => tc.sessionId));
  execSync(`git add -- "${join(state.repoRoot, ".trunk-sync", "timeclock")}"`, { cwd: state.repoRoot, stdio: "ignore" });
}

function commitTimecardChange(state: RepoState, message: string): void {
  try {
    execSync(`git add -- "${join(state.repoRoot, ".trunk-sync", "timeclock")}"`, { cwd: state.repoRoot, stdio: "ignore" });
    execSync(`git -C "${state.repoRoot}" commit -m "${escapeForShell(message)}"`, { stdio: "ignore" });
  } catch {
  }
}

function syncBestEffort(state: RepoState): void {
  if (!state.hasRemote) return;
  try {
    executeSync({ targetBranch: state.targetBranch, currentBranch: state.currentBranch });
  } catch {
  }
}

function formatConflictRoster(state: RepoState, ownSessionId: string | null): string | null {
  const now = new Date();
  const { active } = classifyTimecards(ownSessionId, readTimecards(state.repoRoot), now);
  return formatClockInMessage(active, now);
}

/**
 * Execute a hook plan: stage files, commit, sync.
 * Returns exit code and optional stderr for agent feedback.
 */
export function executePlan(
  plan: HookPlan,
  input: HookInput,
  state: RepoState,
): { exitCode: number; stderr?: string } {
  if (plan.action === "skip") return { exitCode: 0 };

  if (plan.action === "commit-merge") {
    // Stage the file if provided
    const filePath = input.tool_input.file_path;
    if (filePath) {
      execSync(`git add -- "${filePath}"`, { cwd: state.repoRoot });
    }
    touchTimecard(state, input.session_id);
    try {
      execSync(`git commit -m "${escapeForShell(plan.message)}"`, { cwd: state.repoRoot });
    } catch (e: unknown) {
      // Let git's exit code pass through (e.g. 128 for unresolved merge paths)
      const code = getExitCode(e);
      return { exitCode: code, stderr: getStdout(e) };
    }
    if (plan.sync) {
      const syncResult = executeSync(plan.sync);
      if (syncResult.exitCode !== 0) return appendConflictRoster(syncResult, state, input.session_id);
      return syncResult;
    }
    return { exitCode: 0 };
  }

  // commit-and-sync
  const { commit, sync } = plan;

  // Stage deletions
  for (const file of commit.filesToRemove) {
    try {
      execSync(`git -C "${state.repoRoot}" rm --cached --quiet -- "${file}"`, {
        stdio: "ignore",
      });
    } catch {
      // ignore
    }
  }

  // Stage file edits
  for (const file of commit.filesToStage) {
    execSync(`git add -- "${file}"`, { cwd: state.repoRoot });
  }

  // Check if there's anything staged (may have been a no-op)
  try {
    execSync("git diff --cached --quiet", { cwd: state.repoRoot, stdio: "ignore" });
    return { exitCode: 0 }; // nothing to commit
  } catch {
    // has staged changes — continue
  }

  touchTimecard(state, input.session_id);
  reapOldTimecards(state, input.session_id);

  // Try to enrich commit message with task from transcript
  let finalCommit = commit;
  if (input.transcript_path) {
    const expanded = input.transcript_path.replace(/^~/, homedir());
    try {
      const content = readFileSync(expanded, "utf-8");
      const task = extractTaskFromTranscript(content);
      if (task) {
        finalCommit = buildCommitPlanWithTask(input, state, task);
      }
    } catch {
      // best-effort
    }
  }

  // Commit
  if (finalCommit.body) {
    execSync(
      `git commit -m "${escapeForShell(finalCommit.subject)}" -m "${escapeForShell(finalCommit.body)}"`,
      { cwd: state.repoRoot },
    );
  } else {
    execSync(`git commit -m "${escapeForShell(finalCommit.subject)}"`, { cwd: state.repoRoot });
  }

  if (sync) {
    const syncResult = executeSync(sync);
    if (syncResult.exitCode !== 0) return appendConflictRoster(syncResult, state, input.session_id);
    return syncResult;
  }
  return { exitCode: 0 };
}

function appendConflictRoster(
  result: { exitCode: number; stderr?: string },
  state: RepoState,
  ownSessionId: string | null,
): { exitCode: number; stderr?: string } {
  const roster = formatConflictRoster(state, ownSessionId);
  if (!roster) return result;
  return {
    exitCode: result.exitCode,
    stderr: result.stderr ? `${result.stderr}\n\n${roster}` : roster,
  };
}

export function executeSync(sync: SyncPlan): { exitCode: number; stderr?: string } {
  const { targetBranch, currentBranch } = sync;

  // Pull from origin
  let targetBranchExistsUpstream = true;
  try {
    execSync(`git pull origin "${targetBranch}" --no-rebase 2>&1`, { encoding: "utf-8" });
  } catch (e: unknown) {
    const output = getStdout(e);
    if (!/couldn't find remote ref/.test(output)) {
      return conflictExit(output, targetBranch);
    }
    // Target branch doesn't exist on the remote yet — nothing to pull; the push below creates it.
    targetBranchExistsUpstream = false;
  }

  // Merge local target branch into worktree branch
  if (targetBranchExistsUpstream && currentBranch && currentBranch !== targetBranch) {
    try {
      execSync(`git merge "${targetBranch}" --no-edit 2>&1`, { encoding: "utf-8" });
    } catch (e: unknown) {
      return conflictExit(getStdout(e), targetBranch);
    }
  }

  // Push, retry once on failure
  try {
    execSync(`git push origin "HEAD:${targetBranch}" 2>&1`, { encoding: "utf-8" });
  } catch {
    // Retry: pull then push
    try {
      execSync(`git pull origin "${targetBranch}" --no-rebase 2>&1`, { encoding: "utf-8" });
    } catch (e: unknown) {
      return conflictExit(getStdout(e), targetBranch);
    }
    try {
      execSync(`git push origin "HEAD:${targetBranch}" 2>&1`, { encoding: "utf-8" });
    } catch (e: unknown) {
      return pushExit(getStdout(e), targetBranch);
    }
  }

  // Keep local target branch in sync
  try {
    execSync(`git fetch origin "${targetBranch}:${targetBranch}" 2>/dev/null`);
  } catch {
    // If fetch fails (branch checked out), try ff-merge in the worktree
    try {
      const wtOutput = execSync(
        `git worktree list --porcelain`,
        { encoding: "utf-8" },
      );
      const mainWt = findWorktreeForBranch(wtOutput, targetBranch);
      if (mainWt) {
        try {
          execSync(
            `git -C "${mainWt}" merge --ff-only "origin/${targetBranch}" 2>/dev/null`,
          );
        } catch {
          // best-effort
        }
      }
    } catch {
      // ignore
    }
  }

  return { exitCode: 0 };
}

export function findWorktreeForBranch(porcelainOutput: string, branch: string): string | null {
  const blocks = porcelainOutput.split("\n\n");
  for (const block of blocks) {
    const lines = block.split("\n");
    let worktreePath = "";
    let branchRef = "";
    for (const line of lines) {
      if (line.startsWith("worktree ")) worktreePath = line.slice(9);
      if (line.startsWith("branch ")) branchRef = line.slice(7);
    }
    if (branchRef === `refs/heads/${branch}` && worktreePath) {
      return worktreePath;
    }
  }
  return null;
}

function conflictExit(output: string, targetBranch: string): { exitCode: number; stderr: string } {
  return {
    exitCode: 2,
    stderr: `TRUNK-SYNC CONFLICT: ${HOOK_EXPLAINER} Another agent changed the same file, creating a merge conflict. The file now contains git conflict markers (<<<<<<< / ======= / >>>>>>>).\n\ngit output:\n${output}\n\nTo resolve:\n1. Read the conflicting file\n2. Edit it to the correct content (remove the <<<<<<< / ======= / >>>>>>> markers)\n3. Done — this hook will detect the merge state and complete the sync automatically on your next edit\n\nDo NOT run any git commands. The hook handles all git operations — your only job is to fix the file contents using Edit.`,
  };
}

function pushExit(output: string, targetBranch: string): { exitCode: number; stderr: string } {
  return {
    exitCode: 2,
    stderr: `TRUNK-SYNC FAILED: ${HOOK_EXPLAINER} The push to remote failed.\n\ngit output:\n${output}\n\nTo resolve: run "git pull origin ${targetBranch} --no-rebase" then "git push origin HEAD:${targetBranch}". If there are conflicts, read the conflicting files and edit them to remove the conflict markers — the hook will complete the sync on your next edit.`,
  };
}

function escapeForShell(s: string): string {
  return s.replace(/"/g, '\\"');
}

function getExitCode(e: unknown): number {
  if (typeof e === "object" && e !== null && "status" in e) {
    const status = (e as { status: unknown }).status;
    if (typeof status === "number") return status;
  }
  return 1;
}

function getStdout(e: unknown): string {
  if (typeof e === "object" && e !== null && "stdout" in e) {
    return String((e as { stdout: unknown }).stdout);
  }
  if (e instanceof Error) return e.message;
  return String(e);
}
