/**
 * Parse the raw JSON string from hook stdin into a typed HookInput.
 */
export function parseHookInput(json) {
    const raw = JSON.parse(json);
    return {
        tool_name: raw.tool_name ?? null,
        tool_input: raw.tool_input ?? {},
        session_id: raw.session_id ?? null,
        transcript_path: raw.transcript_path ?? null,
    };
}
/**
 * Pure decision logic: given parsed input and repo state, decide what to do.
 * No I/O, no git commands — only data in, plan out.
 */
export function planHook(input, state, runtime) {
    const filePath = input.tool_input.file_path ?? null;
    const sync = buildSyncPlan(state);
    const clockIn = runtime ? buildClockInPlan(input, state, runtime) : null;
    // No file_path and no deleted/modified/untracked files → nothing to do
    if (!filePath &&
        state.deletedFiles.length === 0 &&
        state.modifiedFiles.length === 0 &&
        state.untrackedFiles.length === 0) {
        return { action: "skip" };
    }
    // File path provided but outside the repo → skip
    if (filePath && !state.insideRepo) {
        return { action: "skip" };
    }
    // File path provided but gitignored → skip
    if (filePath && state.gitignored) {
        return { action: "skip" };
    }
    // In merge state → complete the merge
    if (state.inMerge) {
        const relPath = filePath ? state.relPath : summarizeDeletions(state.deletedFiles);
        const sessionPrefix = buildSessionPrefix(input.session_id);
        const message = `${sessionPrefix}resolve merge conflict in ${relPath}`;
        const filesToStage = filePath ? [filePath] : [];
        return {
            action: "commit-merge",
            message,
            sync,
            clockIn,
        };
    }
    // Normal commit path
    const commit = buildCommitPlan(input, state);
    return { action: "commit-and-sync", commit, sync, clockIn };
}
function buildSyncPlan(state) {
    if (!state.hasRemote)
        return null;
    return {
        targetBranch: state.targetBranch,
        currentBranch: state.currentBranch,
    };
}
function buildCommitPlan(input, state) {
    const filePath = input.tool_input.file_path ?? null;
    // Without a file_path, stage every non-deleted change git surfaces: modified
    // tracked files and untracked new files alike (both go through `git add`).
    const changed = [...state.modifiedFiles, ...state.untrackedFiles];
    const filesToStage = filePath ? [filePath] : changed;
    const filesToRemove = filePath ? [] : state.deletedFiles;
    let action;
    let relPath;
    if (filePath) {
        action = (input.tool_name ?? "update").toLowerCase();
        relPath = state.relPath;
    }
    else if (changed.length > 0 && state.deletedFiles.length === 0) {
        action = "update";
        relPath = summarizeDeletions(changed);
    }
    else if (state.deletedFiles.length > 0 && changed.length === 0) {
        action = "delete";
        relPath = summarizeDeletions(state.deletedFiles);
    }
    else {
        action = "update";
        relPath = summarizeDeletions([...changed, ...state.deletedFiles]);
    }
    const sessionPrefix = buildSessionPrefix(input.session_id);
    const subject = `${sessionPrefix}${action} ${relPath}`;
    const body = buildCommitBody(input, filePath ? relPath : null);
    return { filesToStage, filesToRemove, subject, body };
}
/**
 * Build a commit plan with a task-based subject (when transcript extraction succeeds).
 */
export function buildCommitPlanWithTask(input, state, task) {
    const base = buildCommitPlan(input, state);
    if (!task)
        return base;
    const filePath = input.tool_input.file_path ?? null;
    const relPath = filePath
        ? state.relPath
        : summarizeDeletions([...state.modifiedFiles, ...state.untrackedFiles, ...state.deletedFiles]);
    const sessionPrefix = buildSessionPrefix(input.session_id);
    const subject = `${sessionPrefix}${task}`;
    // When task is present, include File: line in body
    let body = `File: ${relPath}`;
    if (input.session_id)
        body += `\nSession: ${input.session_id}`;
    if (input.transcript_path)
        body += `\nTranscriptPath: ${input.transcript_path}`;
    return { ...base, subject, body: body || null };
}
export function buildSessionPrefix(sessionId) {
    if (sessionId)
        return `auto(${sessionId.slice(0, 8)}): `;
    return "auto: ";
}
export function buildCommitBody(input, _relPath) {
    if (!input.session_id)
        return null;
    let body = `Session: ${input.session_id}`;
    body += `\nAgent: ${agentForTool(input.tool_name)}`;
    if (input.transcript_path)
        body += `\nTranscriptPath: ${input.transcript_path}`;
    return body;
}
function agentForTool(toolName) {
    if (toolName === "apply_patch" || toolName === "local_shell")
        return "codex";
    return "claude";
}
/**
 * Extract the first user message from a JSONL transcript.
 * Filters out hook feedback, plan headers, XML tags, and empty lines.
 * Returns first 72 chars or null.
 */
export function extractTaskFromTranscript(content) {
    const lines = content.split("\n");
    for (const line of lines) {
        if (!line.trim())
            continue;
        let parsed;
        try {
            parsed = JSON.parse(line);
        }
        catch {
            continue;
        }
        if (!isUserMessage(parsed))
            continue;
        const msg = parsed.message;
        const texts = extractTextContent(msg.content);
        for (const text of texts) {
            const candidate = filterTaskLine(text);
            if (candidate)
                return candidate.slice(0, 72);
        }
    }
    return null;
}
function isUserMessage(obj) {
    if (typeof obj !== "object" || obj === null)
        return false;
    const rec = obj;
    if (rec.type !== "user")
        return false;
    if (typeof rec.message !== "object" || rec.message === null)
        return false;
    const msg = rec.message;
    return msg.role === "user";
}
function extractTextContent(content) {
    if (typeof content === "string")
        return [content];
    if (Array.isArray(content)) {
        return content.filter((item) => typeof item === "string");
    }
    return [];
}
function filterTaskLine(text) {
    const lines = text.split("\n");
    for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed)
            continue;
        if (trimmed.startsWith("Stop hook feedback:"))
            return null;
        if (trimmed === "Implement the following plan:")
            continue;
        if (trimmed.startsWith("<"))
            continue;
        // Strip leading markdown headers
        const stripped = trimmed.replace(/^#{1,}\s+/, "");
        if (stripped)
            return stripped;
    }
    return null;
}
/**
 * Summarize a list of deleted files: "file.txt (+2 more)"
 */
export function summarizeDeletions(files) {
    if (files.length === 0)
        return "";
    const first = files[0];
    if (files.length === 1)
        return first;
    return `${first} (+${files.length - 1} more)`;
}
export function buildClockInPlan(input, state, runtime) {
    if (!input.session_id)
        return null;
    const now = new Date().toISOString();
    return {
        timecardPath: `.trunk-sync/timeclock/${input.session_id}.json`,
        timecard: {
            sessionId: input.session_id,
            hostname: runtime.hostname,
            clockedInAt: now,
            lastActiveAt: now,
            branch: state.currentBranch || "detached",
        },
    };
}
export const ACTIVE_WINDOW_MS = 60 * 60 * 1000;
export const REAP_TTL_MS = 14 * 24 * 60 * 60 * 1000;
export function classifyTimecards(ownSessionId, timecards, now) {
    const active = [];
    const stale = [];
    const reapable = [];
    for (const tc of timecards) {
        if (tc.sessionId === ownSessionId)
            continue;
        const age = now.getTime() - new Date(tc.lastActiveAt).getTime();
        if (age <= ACTIVE_WINDOW_MS)
            active.push(tc);
        else if (age <= REAP_TTL_MS)
            stale.push(tc);
        else
            reapable.push(tc);
    }
    return { active, stale, reapable };
}
export function formatClockInMessage(active, now, isFirstClockIn) {
    const sections = [];
    if (active.length > 0) {
        const lines = active.map((tc) => {
            const agoStr = formatAge(now.getTime() - new Date(tc.lastActiveAt).getTime());
            return `- ${tc.sessionId.slice(0, 8)} on ${tc.hostname} (branch: ${tc.branch}, ${agoStr} ago)`;
        });
        sections.push(`TRUNK-SYNC ACTIVE: ${active.length} other agent${active.length > 1 ? "s" : ""} active. Continue your work as planned — no action required.`, ...lines);
    }
    if (isFirstClockIn) {
        sections.push("TRUNK-SYNC WIP: Run the test suite before starting. Failing tests are the authoritative signal of unfinished work — any failing test not owned by a currently-active agent is WIP for you to resume. The active roster above is advisory context for who is present.");
    }
    if (active.length > 0) {
        sections.push("If you share resources (ports, test databases, build locks), coordinate accordingly. Otherwise, ignore this message.");
    }
    if (sections.length === 0)
        return null;
    return sections.join("\n");
}
function formatAge(ms) {
    const seconds = Math.floor(ms / 1000);
    if (seconds < 60)
        return `${seconds}s`;
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60)
        return `${minutes}m`;
    const hours = Math.floor(minutes / 60);
    return `${hours}h`;
}
export function formatSessionStartSummary(active, now) {
    if (active.length === 0)
        return null;
    const render = (tc, label) => {
        const age = formatAge(now.getTime() - new Date(tc.lastActiveAt).getTime());
        return `- ${tc.sessionId.slice(0, 8)} on ${tc.hostname} (branch: ${tc.branch}, ${age} ago) — ${label}`;
    };
    const lines = [
        ...active.map((tc) => render(tc, "active: coordinate, do not duplicate")),
    ];
    const count = active.length;
    return [
        `TRUNK-SYNC ACTIVE: ${count} other session${count > 1 ? "s are" : " is"} clocked in. Coordinate around shared resources when needed.`,
        ...lines,
        "Timecards show presence only. Failing tests are the authoritative signal of unfinished work.",
    ].join("\n");
}
