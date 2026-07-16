import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, mkdirSync, writeFileSync, readdirSync, unlinkSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { homedir, hostname } from "node:os";
import type { HookInput, RepoState, HookPlan, CommitPlan, SyncPlan, Timecard, RuntimeContext } from "./hook-types.js";
import { HOOK_EXPLAINER } from "./hook-types.js";
import { extractTaskFromTranscript, buildCommitPlanWithTask, classifyTimecards, formatClockInMessage, formatSessionStartSummary } from "./hook-plan.js";
import { assertSafeSessionId } from "./entry-input.js";

export function gatherRepoState(input: HookInput): RepoState | null {
  const filePath = input.tool_input.file_path ?? null;

  let repoRoot: string;
  let gitDir: string;
  try {
    const [toplevel, dir] = execFileSync("git", ["rev-parse", "--show-toplevel", "--git-dir"], { encoding: "utf-8" }).trim().split("\n");
    repoRoot = toplevel;
    gitDir = dir;
  } catch {
    return null;
  }

  let insideRepo = true;
  let gitignored = false;
  let relPath: string | null = null;

  if (filePath) {
    const resolvedFile = existsSync(filePath) ? realpathSync(filePath) : filePath;
    insideRepo = resolvedFile.startsWith(repoRoot + "/");
    if (insideRepo) {
      relPath = resolvedFile.slice(repoRoot.length + 1);
      try {
        execFileSync("git", ["check-ignore", "-q", "--", relPath], { cwd: repoRoot, stdio: "ignore" });
        gitignored = true;
      } catch {
        gitignored = false;
      }
    }
  }

  let hasRemote = false;
  try {
    execFileSync("git", ["remote", "get-url", "origin"], { stdio: "ignore" });
    hasRemote = true;
  } catch {
  }

  let currentBranch = "";
  const headContent = readFileSync(join(gitDir, "HEAD"), "utf-8").trim();
  if (headContent.startsWith("ref: refs/heads/")) {
    currentBranch = headContent.slice("ref: refs/heads/".length);
  }

  const inMerge = existsSync(join(gitDir, "MERGE_HEAD"));
  let deletedFiles: string[] = [];
  let modifiedFiles: string[] = [];
  let untrackedFiles: string[] = [];
  if (!filePath) {
    deletedFiles = gitPathList(repoRoot, ["ls-files", "--deleted", "-z"]);
    const deletedSet = new Set(deletedFiles);
    const unmergedSet = new Set(gitPathList(repoRoot, ["diff", "--name-only", "--diff-filter=U", "-z"]));
    modifiedFiles = [...new Set(gitPathList(repoRoot, ["diff", "--name-only", "-z"]))]
      .filter((path) => !deletedSet.has(path))
      .filter((path) => !unmergedSet.has(path) || mergePathIsResolved(repoRoot, path));
    untrackedFiles = gitPathList(repoRoot, ["ls-files", "--others", "--exclude-standard", "-z"]);
  }

  return {
    repoRoot,
    gitDir,
    relPath,
    insideRepo,
    gitignored,
    hasRemote,
    currentBranch,
    inMerge,
    deletedFiles,
    modifiedFiles,
    untrackedFiles,
  };
}

function gitPathList(repoRoot: string, args: string[]): string[] {
  const output = execFileSync("git", ["-C", repoRoot, ...args], { encoding: "utf-8" });
  return output.split("\0").filter((path) => path.length > 0);
}

function mergePathIsResolved(repoRoot: string, path: string): boolean {
  const filePath = join(repoRoot, path);
  if (!existsSync(filePath)) return true;
  const content = readFileSync(filePath);
  if (/^(?:<{7}|={7}|>{7})(?: |$)/m.test(content.toString("utf-8"))) return false;
  const conflictBlobs = execFileSync("git", ["-C", repoRoot, "--literal-pathspecs", "ls-files", "-u", "-z", "--", path], { encoding: "utf-8" })
    .split("\0")
    .filter(Boolean)
    .map((record) => record.slice(0, record.indexOf("\t")).split(" ")[1]);
  const worktreeBlob = execFileSync("git", ["-C", repoRoot, "hash-object", "--stdin"], {
    input: content,
    encoding: "utf-8",
  }).trim();
  return !conflictBlobs.includes(worktreeBlob);
}

export function getRuntimeContext(): RuntimeContext {
  return { hostname: hostname() };
}

export function clockIn(repoRoot: string, timecard: Timecard): void {
  const filePath = timecardPath(repoRoot, timecard.sessionId);
  const dir = dirname(filePath);
  mkdirSync(dir, { recursive: true });
  let nextTimecard = { ...timecard };
  if (existsSync(filePath)) {
    const existing = parseTimecard(readFileSync(filePath, "utf-8"), filePath, timecard.sessionId);
    if (existing.clockedInAt) {
      nextTimecard = { ...nextTimecard, clockedInAt: existing.clockedInAt };
    }
  }
  writeFileSync(filePath, JSON.stringify(nextTimecard, null, 2) + "\n");
}

export function readTimecards(repoRoot: string): Timecard[] {
  const dir = join(repoRoot, ".trunk-sync", "timeclock");
  if (!existsSync(dir)) return [];
  const files = readdirSync(dir).filter((f) => f.endsWith(".json"));
  const timecards: Timecard[] = [];
  for (const file of files) {
    const filePath = join(dir, file);
    const expectedSessionId = file.slice(0, -".json".length);
    timecards.push(parseTimecard(readFileSync(filePath, "utf-8"), filePath, expectedSessionId));
  }
  return timecards;
}

function parseTimecard(content: string, filePath: string, expectedSessionId = basename(filePath, ".json")): Timecard {
  let value: unknown;
  try {
    value = JSON.parse(content);
  } catch {
    throw new Error(`Malformed timecard: ${filePath}`);
  }
  if (typeof value !== "object" || value === null) throw new Error(`Malformed timecard: ${filePath}`);
  const card = value as Record<string, unknown>;
  const identityFields = ["sessionId", "hostname", "branch"] as const;
  const timestampFields = ["clockedInAt", "lastActiveAt"] as const;
  if (identityFields.some((field) => typeof card[field] !== "string" || card[field].trim().length === 0)) {
    throw new Error(`Malformed timecard: ${filePath}`);
  }
  if (timestampFields.some((field) => typeof card[field] !== "string" || Number.isNaN(Date.parse(card[field])))) {
    throw new Error(`Malformed timecard: ${filePath}`);
  }
  try {
    assertSafeSessionId(expectedSessionId);
    assertSafeSessionId(card.sessionId as string);
  } catch {
    throw new Error(`Malformed timecard: ${filePath}`);
  }
  if (card.sessionId !== expectedSessionId) throw new Error(`Malformed timecard: ${filePath}`);
  return {
    sessionId: card.sessionId as string,
    hostname: card.hostname as string,
    clockedInAt: card.clockedInAt as string,
    lastActiveAt: card.lastActiveAt as string,
    branch: card.branch as string,
  };
}

export interface SessionStartResult {
  message: string | null;
  warning: string | null;
}

export interface StopResult {
  warning: string | null;
}

export function runSessionStart(state: RepoState, ownSessionId: string | null, runtime: RuntimeContext): SessionStartResult {
  if (!ownSessionId) return { message: null, warning: null };
  if (!state.currentBranch) {
    return { message: null, warning: "TRUNK-SYNC FAILED: A branch must be checked out before session presence can be synchronized." };
  }
  clockIn(state.repoRoot, buildTimecard(ownSessionId, state, runtime));
  const cardPath = `.trunk-sync/timeclock/${ownSessionId}.json`;
  const commitFailure = commitTimecardChange(state, `auto: clock-in ${ownSessionId.slice(0, 8)}`, cardPath);
  const syncFailure = commitFailure !== null ? null : syncBestEffort(state);

  const now = new Date();
  const { active } = classifyTimecards(ownSessionId, readTimecards(state.repoRoot), now);
  const failure = commitFailure ?? syncFailure;
  return {
    message: formatSessionStartSummary(active, now),
    warning: failure !== null
      ? `TRUNK-SYNC WARNING: Session presence is local-only because clock-in could not reach the remote. Remote collaborators cannot see it yet.\n\n${failure}`
      : null,
  };
}

export function runStop(state: RepoState, sessionId: string | null): StopResult {
  if (!sessionId) return { warning: null };
  const cardPath = timecardPath(state.repoRoot, sessionId);
  try {
    parseTimecard(readFileSync(cardPath, "utf-8"), cardPath, sessionId);
    unlinkSync(cardPath);
  } catch (error: unknown) {
    if (isMissingFile(error)) return { warning: null };
    return { warning: clockOutWarning(failureOutput(error, "TRUNK-SYNC FAILED: Clock-out could not remove the local timecard.")) };
  }

  const commitFailure = commitTimecardChange(state, `auto: clock-out ${sessionId.slice(0, 8)}`, `.trunk-sync/timeclock/${sessionId}.json`);
  const syncFailure = commitFailure !== null ? null : syncBestEffort(state);
  const failure = commitFailure ?? syncFailure;
  return {
    warning: failure !== null ? clockOutWarning(failure) : null,
  };
}

export function reapCards(repoRoot: string, ids: string[]): string[] {
  const filePaths = ids.map((id) => timecardPath(repoRoot, id));
  const removed: string[] = [];
  for (const filePath of filePaths) {
    try {
      unlinkSync(filePath);
      removed.push(filePath);
    } catch (error: unknown) {
      if (!isMissingFile(error)) throw error;
    }
  }
  return removed;
}

function isMissingFile(error: unknown): boolean {
  return typeof error === "object" && error !== null && "code" in error && error.code === "ENOENT";
}

function timecardPath(repoRoot: string, sessionId: string): string {
  assertSafeSessionId(sessionId);
  const timeclockDir = resolve(repoRoot, ".trunk-sync", "timeclock");
  const filePath = resolve(timeclockDir, `${sessionId}.json`);
  if (dirname(filePath) !== timeclockDir) throw new Error("session id must remain inside the timeclock directory.");
  return filePath;
}

function clockOutWarning(failure: string): string {
  return `TRUNK-SYNC WARNING: Clock-out remains local; the remote may still show this session as active.\n\n${failure}`;
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
  const cardPath = timecardPath(state.repoRoot, sessionId);
  if (!existsSync(cardPath)) return;
  const card = parseTimecard(readFileSync(cardPath, "utf-8"), cardPath, sessionId);

  card.lastActiveAt = new Date().toISOString();
  card.branch = state.currentBranch || "detached";
  writeFileSync(cardPath, JSON.stringify(card, null, 2) + "\n");
  execFileSync("git", ["-C", state.repoRoot, "--literal-pathspecs", "add", "--", `.trunk-sync/timeclock/${sessionId}.json`], { stdio: "ignore" });
}

function reapOldTimecards(state: RepoState, ownSessionId: string | null): void {
  const { reapable } = classifyTimecards(ownSessionId, readTimecards(state.repoRoot), new Date());
  if (reapable.length === 0) return;
  const removed = reapCards(state.repoRoot, reapable.map((tc) => tc.sessionId));
  if (removed.length === 0) return;
  execFileSync("git", ["--literal-pathspecs", "add", "-A", "--", ...removed], { cwd: state.repoRoot, stdio: "ignore" });
}

function commitTimecardChange(state: RepoState, message: string, cardPath: string): string | null {
  try {
    execFileSync("git", ["--literal-pathspecs", "add", "-A", "--", cardPath], { cwd: state.repoRoot, stdio: "ignore" });
    execFileSync("git", ["-C", state.repoRoot, "--literal-pathspecs", "commit", "-m", message, "--", cardPath], { encoding: "utf-8" });
    return null;
  } catch (e: unknown) {
    return failureOutput(e, "TRUNK-SYNC FAILED: Lifecycle commit failed.");
  }
}

function syncBestEffort(state: RepoState): string | null {
  if (!state.hasRemote) return null;
  try {
    const result = executeSync({ currentBranch: state.currentBranch });
    return result.exitCode === 0 ? null : result.stderr ?? "TRUNK-SYNC FAILED: Lifecycle sync failed.";
  } catch (e: unknown) {
    return getStdout(e);
  }
}

function formatConflictRoster(state: RepoState, ownSessionId: string | null): string | null {
  const now = new Date();
  const { active } = classifyTimecards(ownSessionId, readTimecards(state.repoRoot), now);
  return formatClockInMessage(active, now);
}

export function executePlan(
  plan: HookPlan,
  input: HookInput,
  state: RepoState,
): { exitCode: number; stderr?: string } {
  if (plan.action === "skip") return { exitCode: 0 };

  if (plan.action === "commit-merge") {
    const unmerged = new Set(unmergedPaths(state.repoRoot));
    const unresolved = plan.commit.changedPaths.filter(
      (path) => unmerged.has(path) && !mergePathIsResolved(state.repoRoot, path),
    );
    if (unresolved.length > 0) {
      return conflictExit("The edited path is still unresolved.", state.currentBranch, state.repoRoot);
    }
    stageChangedPaths(plan.commit, state);
    touchTimecard(state, input.session_id);
    try {
      commitChanges(plan.commit, state);
    } catch (e: unknown) {
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

  const { commit, sync } = plan;
  stageChangedPaths(commit, state);

  try {
    execFileSync("git", ["diff", "--cached", "--quiet"], { cwd: state.repoRoot, stdio: "ignore" });
    return { exitCode: 0 };
  } catch {
  }

  touchTimecard(state, input.session_id);
  reapOldTimecards(state, input.session_id);

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
    }
  }

  commitChanges(finalCommit, state);

  if (sync) {
    const syncResult = executeSync(sync);
    if (syncResult.exitCode !== 0) return appendConflictRoster(syncResult, state, input.session_id);
    return syncResult;
  }
  return { exitCode: 0 };
}

function stageChangedPaths(commit: CommitPlan, state: RepoState): void {
  if (commit.changedPaths.length === 0) return;
  execFileSync("git", ["--literal-pathspecs", "add", "-A", "--", ...commit.changedPaths], { cwd: state.repoRoot });
}

function commitChanges(commit: CommitPlan, state: RepoState): void {
  const args = ["commit", "-m", commit.subject];
  if (commit.body) args.push("-m", commit.body);
  execFileSync("git", args, { cwd: state.repoRoot });
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
  const { currentBranch } = sync;
  if (!currentBranch) {
    return {
      exitCode: 2,
      stderr: "TRUNK-SYNC FAILED: A branch must be checked out before trunk-sync can pull or push.",
    };
  }

  const initialRemoteBranch = remoteBranchExists(currentBranch);
  if (typeof initialRemoteBranch !== "boolean") return initialRemoteBranch;
  if (initialRemoteBranch) {
    const pullResult = pullRemoteBranch(currentBranch);
    if (pullResult) return pullResult;
  }

  try {
    execFileSync("git", ["push", "origin", `HEAD:${currentBranch}`], { encoding: "utf-8" });
  } catch {
    const retryRemoteBranch = remoteBranchExists(currentBranch);
    if (typeof retryRemoteBranch !== "boolean") return retryRemoteBranch;
    if (retryRemoteBranch) {
      const pullResult = pullRemoteBranch(currentBranch);
      if (pullResult) return pullResult;
    }
    try {
      execFileSync("git", ["push", "origin", `HEAD:${currentBranch}`], { encoding: "utf-8" });
    } catch (e: unknown) {
      return pushExit(getStdout(e), currentBranch);
    }
  }

  return { exitCode: 0 };
}

function remoteBranchExists(branch: string): boolean | { exitCode: number; stderr: string } {
  try {
    execFileSync("git", ["ls-remote", "--exit-code", "--heads", "origin", `refs/heads/${branch}`], {
      encoding: "utf-8",
    });
    return true;
  } catch (e: unknown) {
    if (getExitCode(e) === 2) return false;
    return remoteFailureExit(getStdout(e));
  }
}

function pullRemoteBranch(branch: string): { exitCode: number; stderr: string } | null {
  try {
    execFileSync("git", ["pull", "origin", branch, "--no-rebase"], { encoding: "utf-8" });
    return null;
  } catch (e: unknown) {
    const output = getStdout(e);
    return hasUnmergedPaths() ? conflictExit(output, branch) : remoteFailureExit(output);
  }
}

function unmergedPaths(repoRoot = process.cwd()): string[] {
  return gitPathList(repoRoot, ["diff", "--name-only", "--diff-filter=U", "-z"]);
}

function hasUnmergedPaths(): boolean {
  return unmergedPaths().length > 0;
}

function conflictExit(output: string, _branch: string, repoRoot = process.cwd()): { exitCode: number; stderr: string } {
  const paths = unmergedPaths(repoRoot);
  const pathList = paths.length > 0 ? paths.map((path) => `- ${path}`).join("\n") : "- Inspect with standalone `git diff --name-only --diff-filter=U`.";
  return {
    exitCode: 2,
    stderr: `TRUNK-SYNC CONFLICT: ${HOOK_EXPLAINER} Another agent changed overlapping content, leaving unmerged paths. Conflicts may be marker-based or markerless.\n\nUnmerged paths:\n${pathList}\n\ngit output:\n${output}\n\nTo resolve:\n1. Read each unmerged path\n2. Edit it to the correct final content, removing conflict markers when present\n3. Done — this hook will verify the resolution and complete the sync automatically on your next edit\n\nDo NOT run write-side git commands. Read-only git inspection is allowed. The hook handles git writes — your only job is to edit the file contents.`,
  };
}

function pushExit(output: string, branch: string): { exitCode: number; stderr: string } {
  return {
    exitCode: 2,
    stderr: `TRUNK-SYNC FAILED: ${HOOK_EXPLAINER} The push to remote branch ${branch} failed after one automatic retry.\n\ngit output:\n${output}\n\nRetry after the underlying condition is corrected; trunk-sync will perform the sync automatically.`,
  };
}

function remoteFailureExit(output: string): { exitCode: number; stderr: string } {
  return {
    exitCode: 2,
    stderr: `TRUNK-SYNC REMOTE FAILURE: ${HOOK_EXPLAINER} The remote operation failed without leaving unmerged paths.\n\ngit output:\n${output}\n\nCorrect the reported remote or working-tree condition, then retry the file operation; trunk-sync will perform the sync automatically.`,
  };
}

function getExitCode(e: unknown): number {
  if (typeof e === "object" && e !== null && "status" in e) {
    const status = (e as { status: unknown }).status;
    if (typeof status === "number") return status;
  }
  return 1;
}

function getStdout(e: unknown): string {
  if (typeof e === "object" && e !== null) {
    const output = e as { stdout?: unknown; stderr?: unknown };
    return `${output.stdout ? String(output.stdout) : ""}${output.stderr ? String(output.stderr) : ""}`;
  }
  if (e instanceof Error) return e.message;
  return String(e);
}

function failureOutput(error: unknown, fallback: string): string {
  const output = getStdout(error).trim();
  return output.length > 0 ? output : fallback;
}
