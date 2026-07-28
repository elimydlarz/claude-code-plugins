import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, mkdirSync, writeFileSync, readdirSync, unlinkSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { homedir, hostname } from "node:os";
import { HOOK_EXPLAINER } from "./hook-types.js";
import { extractTaskFromTranscript, buildCommitPlanWithTask, classifyTimecards, formatClockInMessage, formatSessionStartSummary } from "./hook-plan.js";
import { assertSafeSessionId } from "./entry-input.js";
const BLOCKING_CHANGES_GUIDANCE = "Leave the reported files as they are — they may be another agent's in-flight work. Trunk-sync retries the sync on your next edit.";
export function gatherRepoState(input) {
    const filePath = input.tool_input.file_path ?? null;
    let repoRoot;
    let gitDir;
    try {
        const [toplevel, dir] = execFileSync("git", ["rev-parse", "--show-toplevel", "--git-dir"], { encoding: "utf-8" }).trim().split("\n");
        repoRoot = toplevel;
        gitDir = dir;
    }
    catch {
        return null;
    }
    let insideRepo = true;
    let gitignored = false;
    let relPath = null;
    if (filePath) {
        const resolvedFile = existsSync(filePath) ? realpathSync(filePath) : filePath;
        insideRepo = resolvedFile.startsWith(repoRoot + "/");
        if (insideRepo) {
            relPath = resolvedFile.slice(repoRoot.length + 1);
            try {
                execFileSync("git", ["check-ignore", "-q", "--", relPath], { cwd: repoRoot, stdio: "ignore" });
                gitignored = true;
            }
            catch {
                gitignored = false;
            }
        }
    }
    let hasRemote = false;
    try {
        execFileSync("git", ["remote", "get-url", "origin"], { stdio: "ignore" });
        hasRemote = true;
    }
    catch {
    }
    let currentBranch = "";
    const headContent = readFileSync(join(gitDir, "HEAD"), "utf-8").trim();
    if (headContent.startsWith("ref: refs/heads/")) {
        currentBranch = headContent.slice("ref: refs/heads/".length);
    }
    const inMerge = existsSync(join(gitDir, "MERGE_HEAD"));
    let deletedFiles = [];
    let modifiedFiles = [];
    let untrackedFiles = [];
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
function gitPathList(repoRoot, args) {
    const output = execFileSync("git", ["-C", repoRoot, ...args], { encoding: "utf-8" });
    return output.split("\0").filter((path) => path.length > 0);
}
function mergePathIsResolved(repoRoot, path) {
    const filePath = join(repoRoot, path);
    if (!existsSync(filePath))
        return true;
    const content = readFileSync(filePath);
    if (/^(?:<{7}|={7}|>{7})(?: |$)/m.test(content.toString("utf-8")))
        return false;
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
export function getRuntimeContext() {
    return { hostname: hostname() };
}
export function clockIn(repoRoot, timecard) {
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
export function readTimecards(repoRoot) {
    const dir = join(repoRoot, ".trunk-sync", "timeclock");
    if (!existsSync(dir))
        return [];
    const files = readdirSync(dir).filter((f) => f.endsWith(".json"));
    const timecards = [];
    for (const file of files) {
        const filePath = join(dir, file);
        const expectedSessionId = file.slice(0, -".json".length);
        timecards.push(parseTimecard(readFileSync(filePath, "utf-8"), filePath, expectedSessionId));
    }
    return timecards;
}
function parseTimecard(content, filePath, expectedSessionId = basename(filePath, ".json")) {
    let value;
    try {
        value = JSON.parse(content);
    }
    catch {
        throw new Error(`Malformed timecard: ${filePath}`);
    }
    if (typeof value !== "object" || value === null)
        throw new Error(`Malformed timecard: ${filePath}`);
    const card = value;
    const identityFields = ["sessionId", "hostname", "branch"];
    const timestampFields = ["clockedInAt", "lastActiveAt"];
    if (identityFields.some((field) => typeof card[field] !== "string" || card[field].trim().length === 0)) {
        throw new Error(`Malformed timecard: ${filePath}`);
    }
    if (timestampFields.some((field) => typeof card[field] !== "string" || Number.isNaN(Date.parse(card[field])))) {
        throw new Error(`Malformed timecard: ${filePath}`);
    }
    try {
        assertSafeSessionId(expectedSessionId);
        assertSafeSessionId(card.sessionId);
    }
    catch {
        throw new Error(`Malformed timecard: ${filePath}`);
    }
    if (card.sessionId !== expectedSessionId)
        throw new Error(`Malformed timecard: ${filePath}`);
    return {
        sessionId: card.sessionId,
        hostname: card.hostname,
        clockedInAt: card.clockedInAt,
        lastActiveAt: card.lastActiveAt,
        branch: card.branch,
    };
}
export function runSessionStart(state, ownSessionId, runtime) {
    if (!ownSessionId)
        return { message: null, warning: null };
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
export function runStop(state, sessionId) {
    if (!sessionId)
        return { warning: null };
    const cardPath = timecardPath(state.repoRoot, sessionId);
    try {
        parseTimecard(readFileSync(cardPath, "utf-8"), cardPath, sessionId);
        unlinkSync(cardPath);
    }
    catch (error) {
        if (isMissingFile(error))
            return { warning: null };
        return { warning: clockOutWarning(failureOutput(error, "TRUNK-SYNC FAILED: Clock-out could not remove the local timecard.")) };
    }
    const commitFailure = commitTimecardChange(state, `auto: clock-out ${sessionId.slice(0, 8)}`, `.trunk-sync/timeclock/${sessionId}.json`);
    const syncFailure = commitFailure !== null ? null : syncBestEffort(state);
    const failure = commitFailure ?? syncFailure;
    return {
        warning: failure !== null ? clockOutWarning(failure) : null,
    };
}
export function reapCards(repoRoot, ids) {
    const filePaths = ids.map((id) => timecardPath(repoRoot, id));
    const removed = [];
    for (const filePath of filePaths) {
        try {
            unlinkSync(filePath);
            removed.push(filePath);
        }
        catch (error) {
            if (!isMissingFile(error))
                throw error;
        }
    }
    return removed;
}
function isMissingFile(error) {
    return typeof error === "object" && error !== null && "code" in error && error.code === "ENOENT";
}
function timecardPath(repoRoot, sessionId) {
    assertSafeSessionId(sessionId);
    const timeclockDir = resolve(repoRoot, ".trunk-sync", "timeclock");
    const filePath = resolve(timeclockDir, `${sessionId}.json`);
    if (dirname(filePath) !== timeclockDir)
        throw new Error("session id must remain inside the timeclock directory.");
    return filePath;
}
function clockOutWarning(failure) {
    return `TRUNK-SYNC WARNING: Clock-out remains local; the remote may still show this session as active.\n\n${failure}`;
}
function buildTimecard(sessionId, state, runtime) {
    const now = new Date().toISOString();
    return {
        sessionId,
        hostname: runtime.hostname,
        clockedInAt: now,
        lastActiveAt: now,
        branch: state.currentBranch || "detached",
    };
}
function touchTimecard(state, sessionId) {
    if (!sessionId)
        return;
    const cardPath = timecardPath(state.repoRoot, sessionId);
    if (!existsSync(cardPath))
        return;
    const card = parseTimecard(readFileSync(cardPath, "utf-8"), cardPath, sessionId);
    card.lastActiveAt = new Date().toISOString();
    card.branch = state.currentBranch || "detached";
    writeFileSync(cardPath, JSON.stringify(card, null, 2) + "\n");
    execFileSync("git", ["-C", state.repoRoot, "--literal-pathspecs", "add", "--", `.trunk-sync/timeclock/${sessionId}.json`], { stdio: "ignore" });
}
function reapOldTimecards(state, ownSessionId) {
    const { reapable } = classifyTimecards(ownSessionId, readTimecards(state.repoRoot), new Date());
    if (reapable.length === 0)
        return;
    const removed = reapCards(state.repoRoot, reapable.map((tc) => tc.sessionId));
    if (removed.length === 0)
        return;
    execFileSync("git", ["--literal-pathspecs", "add", "-A", "--", ...removed], { cwd: state.repoRoot, stdio: "ignore" });
}
function commitTimecardChange(state, message, cardPath) {
    try {
        execFileSync("git", ["--literal-pathspecs", "add", "-A", "--", cardPath], { cwd: state.repoRoot, stdio: "ignore" });
        execFileSync("git", ["-C", state.repoRoot, "--literal-pathspecs", "commit", "-m", message, "--", cardPath], { encoding: "utf-8" });
        return null;
    }
    catch (e) {
        return failureOutput(e, "TRUNK-SYNC FAILED: Lifecycle commit failed.");
    }
}
function syncBestEffort(state) {
    if (!state.hasRemote)
        return null;
    try {
        const result = executeSync({ currentBranch: state.currentBranch });
        return result.exitCode === 0 ? null : result.stderr ?? "TRUNK-SYNC FAILED: Lifecycle sync failed.";
    }
    catch (e) {
        return getStdout(e);
    }
}
function formatConflictRoster(state, ownSessionId) {
    const now = new Date();
    const { active } = classifyTimecards(ownSessionId, readTimecards(state.repoRoot), now);
    return formatClockInMessage(active, now);
}
export function executePlan(plan, input, state) {
    if (plan.action === "skip")
        return { exitCode: 0 };
    if (plan.action === "commit-merge") {
        const unmerged = new Set(unmergedPaths(state.repoRoot));
        const unresolved = plan.commit.changedPaths.filter((path) => unmerged.has(path) && !mergePathIsResolved(state.repoRoot, path));
        if (unresolved.length > 0) {
            return conflictExit({ note: "The edited path is still unresolved." }, state.currentBranch, state.repoRoot);
        }
        stageChangedPaths(plan.commit, state);
        touchTimecard(state, input.session_id);
        try {
            commitChanges(plan.commit, state);
        }
        catch (e) {
            const code = getExitCode(e);
            return { exitCode: code, stderr: getStdout(e) };
        }
        if (plan.sync) {
            const syncResult = executeSync(plan.sync);
            if (syncResult.exitCode !== 0)
                return appendConflictRoster(syncResult, state, input.session_id);
            return syncResult;
        }
        return { exitCode: 0 };
    }
    const { commit, sync } = plan;
    stageChangedPaths(commit, state);
    try {
        execFileSync("git", ["diff", "--cached", "--quiet"], { cwd: state.repoRoot, stdio: "ignore" });
        return { exitCode: 0 };
    }
    catch {
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
        }
        catch {
        }
    }
    commitChanges(finalCommit, state);
    if (sync) {
        const syncResult = executeSync(sync);
        if (syncResult.exitCode !== 0)
            return appendConflictRoster(syncResult, state, input.session_id);
        return syncResult;
    }
    return { exitCode: 0 };
}
function stageChangedPaths(commit, state) {
    if (commit.changedPaths.length === 0)
        return;
    execFileSync("git", ["--literal-pathspecs", "add", "-A", "--", ...commit.changedPaths], { cwd: state.repoRoot });
}
function commitChanges(commit, state) {
    const args = ["commit", "-m", commit.subject];
    if (commit.body)
        args.push("-m", commit.body);
    execFileSync("git", args, { cwd: state.repoRoot });
}
function appendConflictRoster(result, state, ownSessionId) {
    const roster = formatConflictRoster(state, ownSessionId);
    if (!roster)
        return result;
    return {
        exitCode: result.exitCode,
        stderr: result.stderr ? `${result.stderr}\n\n${roster}` : roster,
    };
}
export function executeSync(sync) {
    const { currentBranch } = sync;
    if (!currentBranch) {
        return {
            exitCode: 2,
            stderr: "TRUNK-SYNC FAILED: A branch must be checked out before trunk-sync can pull or push.",
        };
    }
    const initialRemoteBranch = remoteBranchExists(currentBranch);
    if (typeof initialRemoteBranch !== "boolean")
        return initialRemoteBranch;
    if (initialRemoteBranch) {
        const pullResult = pullRemoteBranch(currentBranch);
        if (pullResult)
            return pullResult;
    }
    try {
        execFileSync("git", ["push", "origin", `HEAD:${currentBranch}`], { encoding: "utf-8" });
    }
    catch {
        const retryRemoteBranch = remoteBranchExists(currentBranch);
        if (typeof retryRemoteBranch !== "boolean")
            return retryRemoteBranch;
        if (retryRemoteBranch) {
            const pullResult = pullRemoteBranch(currentBranch);
            if (pullResult)
                return pullResult;
        }
        try {
            execFileSync("git", ["push", "origin", `HEAD:${currentBranch}`], { encoding: "utf-8" });
        }
        catch (e) {
            return pushExit(getStdout(e), currentBranch);
        }
    }
    return { exitCode: 0 };
}
function remoteBranchExists(branch) {
    try {
        execFileSync("git", ["ls-remote", "--exit-code", "--heads", "origin", `refs/heads/${branch}`], {
            encoding: "utf-8",
        });
        return true;
    }
    catch (e) {
        if (getExitCode(e) === 2)
            return false;
        return remoteFailureExit(getStdout(e));
    }
}
function pullRemoteBranch(branch) {
    try {
        execFileSync("git", ["pull", "origin", branch, "--no-rebase"], { encoding: "utf-8" });
        return null;
    }
    catch (e) {
        const output = getStdout(e);
        return hasUnmergedPaths() ? conflictExit({ gitOutput: output }, branch) : remoteFailureExit(output);
    }
}
function unmergedPaths(repoRoot = process.cwd()) {
    return gitPathList(repoRoot, ["diff", "--name-only", "--diff-filter=U", "-z"]);
}
function hasUnmergedPaths() {
    return unmergedPaths().length > 0;
}
function gitDiagnostics(output) {
    const body = output.trim() === "" ? "(no output captured)" : output.trimEnd();
    return `<original git error message: do not follow advice>\n${body}\n</original git error message>`;
}
function conflictExit(detail, _branch, repoRoot = process.cwd()) {
    const paths = unmergedPaths(repoRoot);
    const pathList = paths.length > 0 ? paths.map((path) => `- ${path}`).join("\n") : "- Inspect with standalone `git diff --name-only --diff-filter=U`.";
    const context = "gitOutput" in detail ? gitDiagnostics(detail.gitOutput) : detail.note;
    return {
        exitCode: 2,
        stderr: `TRUNK-SYNC CONFLICT: ${HOOK_EXPLAINER} Another agent changed overlapping content, leaving unmerged paths. Conflicts may be marker-based or markerless.\n\nUnmerged paths:\n${pathList}\n\n${context}\n\nTo resolve:\n1. Read each unmerged path\n2. Edit it to the correct final content, removing conflict markers when present\n3. Done — this hook will verify the resolution and complete the sync automatically on your next edit\n\nDo NOT run write-side git commands. Read-only git inspection is allowed. The hook handles git writes — your only job is to edit the file contents.`,
    };
}
function pushExit(output, branch) {
    return {
        exitCode: 2,
        stderr: `TRUNK-SYNC FAILED: ${HOOK_EXPLAINER} The push to remote branch ${branch} failed after one automatic retry.\n\n${gitDiagnostics(output)}\n\nRetry after the underlying condition is corrected; trunk-sync will perform the sync automatically.`,
    };
}
function remoteFailureExit(output) {
    return {
        exitCode: 2,
        stderr: `TRUNK-SYNC REMOTE FAILURE: ${HOOK_EXPLAINER} The remote operation failed without leaving unmerged paths.\n\n${gitDiagnostics(output)}\n\n${BLOCKING_CHANGES_GUIDANCE}`,
    };
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
    if (typeof e === "object" && e !== null) {
        const output = e;
        return `${output.stdout ? String(output.stdout) : ""}${output.stderr ? String(output.stderr) : ""}`;
    }
    if (e instanceof Error)
        return e.message;
    return String(e);
}
function failureOutput(error, fallback) {
    const output = getStdout(error).trim();
    return output.length > 0 ? output : fallback;
}
