export function parseHookInput(json) {
    const raw = JSON.parse(json);
    return {
        tool_name: raw.tool_name ?? null,
        tool_input: raw.tool_input ?? {},
        turn_id: raw.turn_id ?? null,
        session_id: raw.session_id ?? null,
        transcript_path: raw.transcript_path ?? null,
        cwd: raw.cwd ?? null,
    };
}
export function planHook(input, state) {
    const filePath = input.tool_input.file_path ?? null;
    const sync = buildSyncPlan(state);
    if (!filePath &&
        state.deletedFiles.length === 0 &&
        state.modifiedFiles.length === 0 &&
        state.untrackedFiles.length === 0) {
        return { action: "skip" };
    }
    if (filePath && !state.insideRepo) {
        return { action: "skip" };
    }
    if (filePath && state.gitignored) {
        return { action: "skip" };
    }
    if (state.inMerge) {
        const relPath = filePath ? state.relPath : summarizeDeletions(state.deletedFiles);
        const sessionPrefix = buildSessionPrefix(input.session_id);
        const message = `${sessionPrefix}resolve merge conflict in ${relPath}`;
        const filesToStage = filePath ? [filePath] : [];
        return {
            action: "commit-merge",
            message,
            sync,
        };
    }
    const commit = buildCommitPlan(input, state);
    return { action: "commit-and-sync", commit, sync };
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
    const provenance = buildCommitBody(input, relPath);
    const body = provenance ? `File: ${relPath}\n${provenance}` : `File: ${relPath}`;
    return { ...base, subject, body };
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
    return body;
}
function agentForTool(toolName) {
    if (toolName === "apply_patch" || toolName === "local_shell")
        return "codex";
    return "claude";
}
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
        const stripped = trimmed.replace(/^#{1,}\s+/, "");
        if (stripped)
            return stripped;
    }
    return null;
}
export function summarizeDeletions(files) {
    if (files.length === 0)
        return "";
    const first = files[0];
    if (files.length === 1)
        return first;
    return `${first} (+${files.length - 1} more)`;
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
export function formatClockInMessage(active, now) {
    const sections = [];
    if (active.length > 0) {
        const lines = active.map((tc) => {
            const agoStr = formatAge(now.getTime() - new Date(tc.lastActiveAt).getTime());
            return `- ${tc.sessionId.slice(0, 8)} on ${tc.hostname} (branch: ${tc.branch}, ${agoStr} ago)`;
        });
        sections.push(`TRUNK-SYNC ACTIVE: ${active.length} other agent${active.length > 1 ? "s" : ""} active. Continue your work as planned — no action required.`, ...lines);
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
