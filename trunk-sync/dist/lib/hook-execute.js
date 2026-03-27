import { execSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, mkdirSync, copyFileSync, writeFileSync, readdirSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { homedir, hostname } from "node:os";
import { readConfig } from "../commands/config.js";
import { HOOK_EXPLAINER } from "./hook-types.js";
import { extractTaskFromTranscript, buildCommitPlanWithTask, classifySessions, formatAwarenessMessage } from "./hook-plan.js";
/**
 * Gather the current git repo state needed for planning.
 * Runs git commands — this is the I/O boundary.
 */
export function gatherRepoState(input) {
    const filePath = input.tool_input.file_path ?? null;
    let repoRoot;
    try {
        repoRoot = execSync("git rev-parse --show-toplevel", { encoding: "utf-8" }).trim();
    }
    catch {
        return null; // not in a git repo
    }
    const gitDir = execSync("git rev-parse --git-dir", { encoding: "utf-8" }).trim();
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
    let hasRemote = true;
    try {
        execSync("git remote get-url origin", { stdio: "ignore" });
    }
    catch {
        hasRemote = false;
    }
    let targetBranch = "";
    if (hasRemote) {
        try {
            const ref = execSync("git symbolic-ref refs/remotes/origin/HEAD", {
                encoding: "utf-8",
            }).trim();
            targetBranch = ref.replace("refs/remotes/origin/", "");
        }
        catch {
            targetBranch = "main";
        }
    }
    let currentBranch = "";
    try {
        currentBranch = execSync("git symbolic-ref --short HEAD", { encoding: "utf-8" }).trim();
    }
    catch {
        // detached HEAD
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
    };
}
// --- Session awareness I/O ---
export function getRuntimeContext() {
    return { pid: process.pid, hostname: hostname() };
}
export function writeSessionHeartbeat(repoRoot, plan) {
    const dir = join(repoRoot, ".trunk-sync", "sessions");
    mkdirSync(dir, { recursive: true });
    // Preserve startedAt from existing heartbeat if present
    const filePath = join(repoRoot, plan.heartbeatPath);
    let heartbeat = plan.heartbeat;
    try {
        const existing = JSON.parse(readFileSync(filePath, "utf-8"));
        if (existing.startedAt) {
            heartbeat = { ...heartbeat, startedAt: existing.startedAt };
        }
    }
    catch {
        // No existing file — use plan's startedAt
    }
    writeFileSync(filePath, JSON.stringify(heartbeat, null, 2) + "\n");
}
export function readAllSessions(repoRoot) {
    const dir = join(repoRoot, ".trunk-sync", "sessions");
    if (!existsSync(dir))
        return [];
    const files = readdirSync(dir).filter((f) => f.endsWith(".json"));
    const sessions = [];
    for (const file of files) {
        try {
            const content = readFileSync(join(dir, file), "utf-8");
            sessions.push(JSON.parse(content));
        }
        catch {
            // Skip unparseable files
        }
    }
    return sessions;
}
export function isProcessAlive(pid) {
    try {
        process.kill(pid, 0);
        return true;
    }
    catch {
        return false;
    }
}
export function pruneStaleSessionFiles(repoRoot, staleIds) {
    const removed = [];
    for (const id of staleIds) {
        const filePath = join(repoRoot, ".trunk-sync", "sessions", `${id}.json`);
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
    const path = join(tmpdir(), `trunk-sync-warning-${sessionId}`);
    try {
        return parseInt(readFileSync(path, "utf-8"), 10);
    }
    catch {
        return null;
    }
}
function writeThrottleTimestamp(sessionId, now) {
    const path = join(tmpdir(), `trunk-sync-warning-${sessionId}`);
    writeFileSync(path, String(now));
}
function tmpdir() {
    return process.env.TMPDIR || "/tmp";
}
const THROTTLE_MS = 5 * 60 * 1000; // 5 minutes
/**
 * Run session awareness: write heartbeat, prune stale, check for others.
 * Returns awareness message if other sessions are active and throttle allows.
 */
function executeSessionAwareness(session, state) {
    try {
        writeSessionHeartbeat(state.repoRoot, session);
        const allSessions = readAllSessions(state.repoRoot);
        const now = new Date();
        const { active, stale } = classifySessions(session.heartbeat.sessionId, allSessions, now, session.heartbeat.hostname, isProcessAlive);
        // Prune stale sessions
        if (stale.length > 0) {
            pruneStaleSessionFiles(state.repoRoot, stale);
        }
        // Stage session directory (heartbeat + any removals)
        const sessionsDir = join(state.repoRoot, ".trunk-sync", "sessions");
        try {
            execSync(`git add -- "${sessionsDir}"`, { cwd: state.repoRoot, stdio: "ignore" });
        }
        catch {
            // best-effort
        }
        // Check throttle before returning awareness message
        if (active.length > 0) {
            const lastWarning = readThrottleTimestamp(session.heartbeat.sessionId);
            const nowMs = now.getTime();
            if (lastWarning === null || (nowMs - lastWarning) >= THROTTLE_MS) {
                writeThrottleTimestamp(session.heartbeat.sessionId, nowMs);
                return formatAwarenessMessage(active, now);
            }
        }
        return null;
    }
    catch {
        // Session awareness is best-effort — never fail the hook
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
        // Session awareness (heartbeat + prune + stage)
        const awarenessMsg = plan.session ? executeSessionAwareness(plan.session, state) : null;
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
            if (awarenessMsg)
                return { exitCode: 2, stderr: awarenessMsg };
            return syncResult;
        }
        if (awarenessMsg)
            return { exitCode: 2, stderr: awarenessMsg };
        return { exitCode: 0 };
    }
    // commit-and-sync
    const { commit, sync, session } = plan;
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
    // Session awareness: write heartbeat, prune stale, stage session dir
    const awarenessMsg = session ? executeSessionAwareness(session, state) : null;
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
        if (awarenessMsg)
            return { exitCode: 2, stderr: awarenessMsg };
        return syncResult;
    }
    if (awarenessMsg)
        return { exitCode: 2, stderr: awarenessMsg };
    return { exitCode: 0 };
}
function amendWithTranscriptSnapshot(input, state) {
    try {
        const config = readConfig();
        if (config.get("commit-transcripts") !== "true")
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
    try {
        execSync(`git pull origin "${targetBranch}" --no-rebase 2>&1`, { encoding: "utf-8" });
    }
    catch (e) {
        return conflictExit(getStdout(e), targetBranch);
    }
    // Merge local target branch into worktree branch
    if (currentBranch && currentBranch !== targetBranch) {
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
