import { execSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, mkdirSync, copyFileSync, writeFileSync, readdirSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { homedir, hostname } from "node:os";
import { readConfig } from "../commands/config.js";
import { HOOK_EXPLAINER } from "./hook-types.js";
import { extractTaskFromTranscript, buildCommitPlanWithTask, classifyTimecards, formatClockInMessage, formatSessionStartSummary } from "./hook-plan.js";
/** Absent a `target-branch` override in `.trunk-sync/config`, agents sync to a dedicated branch — not the repo's actual default branch — so auto-commits never land directly on it. */
const DEFAULT_TARGET_BRANCH = "agents";
/**
 * Gather the current git repo state needed for planning.
 * Runs git commands — this is the I/O boundary.
 */
export function gatherRepoState(input) {
    const filePath = input.tool_input.file_path ?? null;
    let repoRoot;
    let gitDir;
    try {
        const [toplevel, dir] = execSync("git rev-parse --show-toplevel --git-dir", { encoding: "utf-8" }).trim().split("\n");
        repoRoot = toplevel;
        gitDir = dir;
    }
    catch {
        return null; // not in a git repo
    }
    let insideRepo = true;
    let gitignored = false;
    let relPath = null;
    if (filePath) {
        // Resolve symlinks so /var/... matches /private/var/... on macOS
        const resolvedFile = existsSync(filePath) ? realpathSync(filePath) : filePath;
        insideRepo = resolvedFile.startsWith(repoRoot + "/");
        if (insideRepo) {
            relPath = resolvedFile.slice(repoRoot.length + 1);
            try {
                execSync(`git check-ignore -q -- "${filePath}"`, { stdio: "ignore" });
                gitignored = true;
            }
            catch {
                gitignored = false;
            }
        }
    }
    let hasRemote = false;
    try {
        execSync("git remote get-url origin", { stdio: "ignore" });
        hasRemote = true;
    }
    catch {
        // no remote
    }
    let targetBranch = "";
    if (hasRemote) {
        targetBranch = readConfig(repoRoot).get("target-branch") ?? DEFAULT_TARGET_BRANCH;
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
    }
    catch {
        hasStagedChanges = true;
    }
    let deletedFiles = [];
    let modifiedFiles = [];
    let untrackedFiles = [];
    if (!filePath) {
        try {
            const deleted = execSync(`git -C "${repoRoot}" ls-files --deleted`, {
                encoding: "utf-8",
            }).trim();
            if (deleted)
                deletedFiles = deleted.split("\n");
        }
        catch {
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
        }
        catch {
            // ignore
        }
        try {
            const untracked = execSync(`git -C "${repoRoot}" ls-files --others --exclude-standard`, { encoding: "utf-8" }).trim();
            if (untracked)
                untrackedFiles = untracked.split("\n");
        }
        catch {
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
// --- Presence: clock-in (heartbeat) and reaping ---
export function getRuntimeContext() {
    return { hostname: hostname() };
}
/** Clock in: write or update this agent's timecard on the timeclock. */
export function clockIn(repoRoot, plan, task) {
    const dir = join(repoRoot, ".trunk-sync", "timeclock");
    mkdirSync(dir, { recursive: true });
    const filePath = join(repoRoot, plan.timecardPath);
    // Preserve clockedInAt and agent-authored progress from existing timecard if present
    let timecard = { ...plan.timecard, task };
    try {
        const existing = JSON.parse(readFileSync(filePath, "utf-8"));
        if (existing.clockedInAt) {
            timecard = { ...timecard, clockedInAt: existing.clockedInAt };
        }
        timecard = {
            ...timecard,
            lastStep: existing.lastStep ?? null,
            remainingSteps: existing.remainingSteps ?? null,
        };
    }
    catch {
        // No existing file — use plan's clockedInAt and null progress
    }
    writeFileSync(filePath, JSON.stringify(timecard, null, 2) + "\n");
}
/** Read all timecards from the timeclock directory. */
export function readTimecards(repoRoot) {
    const dir = join(repoRoot, ".trunk-sync", "timeclock");
    if (!existsSync(dir))
        return [];
    const files = readdirSync(dir).filter((f) => f.endsWith(".json"));
    const timecards = [];
    for (const file of files) {
        try {
            const content = readFileSync(join(dir, file), "utf-8");
            timecards.push(JSON.parse(content));
        }
        catch {
            // Skip unparseable files
        }
    }
    return timecards;
}
/**
 * Build the session-start message: hand the starting agent its own session id and the
 * record-progress instruction, then append the handover roster of active + stale sessions.
 * Returns null only when no session id is available.
 */
export function runSessionStart(repoRoot, ownSessionId) {
    if (!ownSessionId)
        return null;
    const intro = `TRUNK-SYNC SESSION: your session id is ${ownSessionId}. Record your progress as you work and before you pause:\n` +
        `  trunk-sync progress ${ownSessionId} --last "<step you just finished>" --next "<steps still to do>"`;
    const now = new Date();
    const { active, stale } = classifyTimecards(ownSessionId, readTimecards(repoRoot), now);
    const roster = formatSessionStartSummary(active, stale, now);
    return roster ? `${intro}\n\n${roster}` : intro;
}
/**
 * Heartbeat-only Stop hook: if this session has a timecard, bump its heartbeat and sync it
 * so remote readers stay fresh through a long no-edit turn. Never forces the agent (no exit 2).
 * No-ops when a recent tool-use sync already refreshed the heartbeat, and creates no card for
 * a session that never edited.
 */
export function runStop(state, sessionId) {
    if (!sessionId)
        return;
    const cardPath = join(state.repoRoot, ".trunk-sync", "timeclock", `${sessionId}.json`);
    let card;
    try {
        card = JSON.parse(readFileSync(cardPath, "utf-8"));
    }
    catch {
        return; // no card — a session that never edited has no handover to keep alive
    }
    const age = Date.now() - new Date(card.lastActiveAt).getTime();
    if (age < HEARTBEAT_STALE_MS)
        return; // a recent tool-use sync already refreshed the heartbeat
    card.lastActiveAt = new Date().toISOString();
    try {
        writeFileSync(cardPath, JSON.stringify(card, null, 2) + "\n");
        execSync(`git -C "${state.repoRoot}" add -- ".trunk-sync/timeclock/${sessionId}.json"`, { stdio: "ignore" });
        execSync(`git -C "${state.repoRoot}" commit -m "auto: heartbeat ${sessionId.slice(0, 8)}"`, {
            stdio: "ignore",
        });
    }
    catch {
        return; // nothing to commit or write failed — best-effort
    }
    if (state.hasRemote) {
        try {
            executeSync({ targetBranch: state.targetBranch, currentBranch: state.currentBranch });
        }
        catch {
            // best-effort: the next tool-use sync retries; the Stop hook always exits 0
        }
    }
}
/** Reap the given (reapable) cards by removing their timecard files; returns removed paths. */
export function reapCards(repoRoot, ids) {
    const removed = [];
    for (const id of ids) {
        const filePath = join(repoRoot, ".trunk-sync", "timeclock", `${id}.json`);
        try {
            unlinkSync(filePath);
            removed.push(filePath);
        }
        catch {
            // Already gone
        }
    }
    return removed;
}
function readThrottleTimestamp(sessionId) {
    const path = join(tmpdir(), `trunk-sync-clockin-${sessionId}`);
    try {
        return parseInt(readFileSync(path, "utf-8"), 10);
    }
    catch {
        return null;
    }
}
function writeThrottleTimestamp(sessionId, now) {
    const path = join(tmpdir(), `trunk-sync-clockin-${sessionId}`);
    writeFileSync(path, String(now));
}
function tmpdir() {
    return process.env.TMPDIR || "/tmp";
}
const THROTTLE_MS = 5 * 60 * 1000; // 5 minutes
/** How stale a heartbeat must be before the Stop hook refreshes and re-syncs it. */
const HEARTBEAT_STALE_MS = 30 * 60 * 1000; // 30 minutes — half the active display window
/**
 * Extract the agent's current task from the transcript (same logic as commit enrichment).
 * Returns null if transcript is unavailable or unparseable.
 */
function extractTask(input) {
    if (!input.transcript_path)
        return null;
    const expanded = input.transcript_path.replace(/^~/, homedir());
    try {
        const content = readFileSync(expanded, "utf-8");
        return extractTaskFromTranscript(content);
    }
    catch {
        return null;
    }
}
/**
 * Clock in, reap abandoned cards (heartbeat past the TTL), and check who else is active.
 * Returns a message if other agents are active and throttle allows.
 */
function executeClockIn(plan, input, state) {
    try {
        const task = extractTask(input);
        clockIn(state.repoRoot, plan, task);
        const allTimecards = readTimecards(state.repoRoot);
        const now = new Date();
        const { active, reapable } = classifyTimecards(plan.timecard.sessionId, allTimecards, now);
        if (reapable.length > 0) {
            reapCards(state.repoRoot, reapable.map((tc) => tc.sessionId));
        }
        // Stage timeclock directory (timecard + any removals)
        const timeclockDir = join(state.repoRoot, ".trunk-sync", "timeclock");
        try {
            execSync(`git add -- "${timeclockDir}"`, { cwd: state.repoRoot, stdio: "ignore" });
        }
        catch {
            // best-effort
        }
        // The first clock-in of a session always speaks (run the tests, resume WIP);
        // the co-worker roster repeats at most once per throttle window.
        const lastWarning = readThrottleTimestamp(plan.timecard.sessionId);
        const nowMs = now.getTime();
        const isFirstClockIn = lastWarning === null;
        const throttleElapsed = isFirstClockIn || (nowMs - lastWarning) >= THROTTLE_MS;
        if (isFirstClockIn || (active.length > 0 && throttleElapsed)) {
            writeThrottleTimestamp(plan.timecard.sessionId, nowMs);
            return formatClockInMessage(active, now, isFirstClockIn);
        }
        return null;
    }
    catch {
        // Clock-in is best-effort — never fail the hook
        return null;
    }
}
/**
 * Execute a hook plan: stage files, commit, sync.
 * Returns exit code and optional stderr for agent feedback.
 */
export function executePlan(plan, input, state) {
    if (plan.action === "skip")
        return { exitCode: 0 };
    if (plan.action === "commit-merge") {
        // Clock in and check who else is working
        const clockInMsg = plan.clockIn ? executeClockIn(plan.clockIn, input, state) : null;
        // Stage the file if provided
        const filePath = input.tool_input.file_path;
        if (filePath) {
            execSync(`git add -- "${filePath}"`);
        }
        try {
            execSync(`git commit -m "${escapeForShell(plan.message)}"`);
        }
        catch (e) {
            // Let git's exit code pass through (e.g. 128 for unresolved merge paths)
            const code = getExitCode(e);
            return { exitCode: code, stderr: getStdout(e) };
        }
        if (plan.sync) {
            const syncResult = executeSync(plan.sync);
            if (syncResult.exitCode !== 0)
                return syncResult;
            if (clockInMsg)
                return { exitCode: 2, stderr: clockInMsg };
            return syncResult;
        }
        if (clockInMsg)
            return { exitCode: 2, stderr: clockInMsg };
        return { exitCode: 0 };
    }
    // commit-and-sync
    const { commit, sync, clockIn: clockInPlan } = plan;
    // Stage deletions
    for (const file of commit.filesToRemove) {
        try {
            execSync(`git -C "${state.repoRoot}" rm --cached --quiet -- "${file}"`, {
                stdio: "ignore",
            });
        }
        catch {
            // ignore
        }
    }
    // Stage file edits
    for (const file of commit.filesToStage) {
        execSync(`git add -- "${file}"`);
    }
    // Clock in and check who else is working
    const clockInMsg = clockInPlan ? executeClockIn(clockInPlan, input, state) : null;
    // Check if there's anything staged (may have been a no-op)
    try {
        execSync("git diff --cached --quiet", { stdio: "ignore" });
        return { exitCode: 0 }; // nothing to commit
    }
    catch {
        // has staged changes — continue
    }
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
        }
        catch {
            // best-effort
        }
    }
    // Commit
    if (finalCommit.body) {
        execSync(`git commit -m "${escapeForShell(finalCommit.subject)}" -m "${escapeForShell(finalCommit.body)}"`);
    }
    else {
        execSync(`git commit -m "${escapeForShell(finalCommit.subject)}"`);
    }
    // Snapshot transcript into the commit (opt-in via config)
    amendWithTranscriptSnapshot(input, state);
    if (sync) {
        const syncResult = executeSync(sync);
        if (syncResult.exitCode !== 0)
            return syncResult;
        if (clockInMsg)
            return { exitCode: 2, stderr: clockInMsg };
        return syncResult;
    }
    if (clockInMsg)
        return { exitCode: 2, stderr: clockInMsg };
    return { exitCode: 0 };
}
function amendWithTranscriptSnapshot(input, state) {
    try {
        const config = readConfig(state.repoRoot);
        if (config.get("commit-transcripts") === "false")
            return;
        if (!input.transcript_path || !input.session_id)
            return;
        const expanded = input.transcript_path.replace(/^~/, homedir());
        if (!existsSync(expanded))
            return;
        const snapshotDir = join(state.repoRoot, ".transcripts");
        mkdirSync(snapshotDir, { recursive: true });
        const shortSession = input.session_id.slice(0, 8);
        const epoch = Math.floor(Date.now() / 1000);
        const snapshotName = `${shortSession}-${epoch}.jsonl`;
        copyFileSync(expanded, join(snapshotDir, snapshotName));
        execSync(`git add -- "${snapshotDir}"`, { cwd: state.repoRoot });
        execSync(`git commit --amend --no-edit`, { cwd: state.repoRoot });
    }
    catch {
        // best-effort — don't fail the hook if snapshot fails
    }
}
export function executeSync(sync) {
    const { targetBranch, currentBranch } = sync;
    // Pull from origin
    let targetBranchExistsUpstream = true;
    try {
        execSync(`git pull origin "${targetBranch}" --no-rebase 2>&1`, { encoding: "utf-8" });
    }
    catch (e) {
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
        }
        catch (e) {
            return conflictExit(getStdout(e), targetBranch);
        }
    }
    // Push, retry once on failure
    try {
        execSync(`git push origin "HEAD:${targetBranch}" 2>&1`, { encoding: "utf-8" });
    }
    catch {
        // Retry: pull then push
        try {
            execSync(`git pull origin "${targetBranch}" --no-rebase 2>&1`, { encoding: "utf-8" });
        }
        catch (e) {
            return conflictExit(getStdout(e), targetBranch);
        }
        try {
            execSync(`git push origin "HEAD:${targetBranch}" 2>&1`, { encoding: "utf-8" });
        }
        catch (e) {
            return pushExit(getStdout(e), targetBranch);
        }
    }
    // Keep local target branch in sync
    try {
        execSync(`git fetch origin "${targetBranch}:${targetBranch}" 2>/dev/null`);
    }
    catch {
        // If fetch fails (branch checked out), try ff-merge in the worktree
        try {
            const wtOutput = execSync(`git worktree list --porcelain`, { encoding: "utf-8" });
            const mainWt = findWorktreeForBranch(wtOutput, targetBranch);
            if (mainWt) {
                try {
                    execSync(`git -C "${mainWt}" merge --ff-only "origin/${targetBranch}" 2>/dev/null`);
                }
                catch {
                    // best-effort
                }
            }
        }
        catch {
            // ignore
        }
    }
    return { exitCode: 0 };
}
export function findWorktreeForBranch(porcelainOutput, branch) {
    const blocks = porcelainOutput.split("\n\n");
    for (const block of blocks) {
        const lines = block.split("\n");
        let worktreePath = "";
        let branchRef = "";
        for (const line of lines) {
            if (line.startsWith("worktree "))
                worktreePath = line.slice(9);
            if (line.startsWith("branch "))
                branchRef = line.slice(7);
        }
        if (branchRef === `refs/heads/${branch}` && worktreePath) {
            return worktreePath;
        }
    }
    return null;
}
function conflictExit(output, targetBranch) {
    return {
        exitCode: 2,
        stderr: `TRUNK-SYNC CONFLICT: ${HOOK_EXPLAINER} Another agent changed the same file, creating a merge conflict. The file now contains git conflict markers (<<<<<<< / ======= / >>>>>>>).\n\ngit output:\n${output}\n\nTo resolve:\n1. Read the conflicting file\n2. Edit it to the correct content (remove the <<<<<<< / ======= / >>>>>>> markers)\n3. Done — this hook will detect the merge state and complete the sync automatically on your next edit\n\nDo NOT run any git commands. The hook handles all git operations — your only job is to fix the file contents using Edit.`,
    };
}
function pushExit(output, targetBranch) {
    return {
        exitCode: 2,
        stderr: `TRUNK-SYNC FAILED: ${HOOK_EXPLAINER} The push to remote failed.\n\ngit output:\n${output}\n\nTo resolve: run "git pull origin ${targetBranch} --no-rebase" then "git push origin HEAD:${targetBranch}". If there are conflicts, read the conflicting files and edit them to remove the conflict markers — the hook will complete the sync on your next edit.`,
    };
}
function escapeForShell(s) {
    return s.replace(/"/g, '\\"');
}
function getExitCode(e) {
    if (typeof e === "object" && e !== null && "status" in e) {
        const status = e.status;
        if (typeof status === "number")
            return status;
    }
    return 1;
}
function getStdout(e) {
    if (typeof e === "object" && e !== null && "stdout" in e) {
        return String(e.stdout);
    }
    if (e instanceof Error)
        return e.message;
    return String(e);
}
