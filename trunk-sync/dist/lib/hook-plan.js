import { isInputObject, parseInputObject } from "./entry-input.js";
export function parseHookInput(json) {
    const raw = parseInputObject(json);
    const toolInput = raw.tool_input ?? {};
    if (!isInputObject(toolInput))
        throw new Error("tool_input must be a JSON object.");
    const filePath = optionalString(toolInput, "file_path");
    return {
        tool_name: optionalString(raw, "tool_name"),
        tool_input: filePath === null ? {} : { file_path: filePath },
        turn_id: optionalString(raw, "turn_id"),
        session_id: optionalString(raw, "session_id"),
        transcript_path: optionalString(raw, "transcript_path"),
        cwd: optionalString(raw, "cwd"),
    };
}
function optionalString(record, key) {
    const value = record[key];
    if (value === undefined || value === null)
        return null;
    if (typeof value !== "string")
        throw new Error(`${key} must be a string when provided.`);
    return value;
}
export function planHook(input, state) {
    const filePath = input.tool_input.file_path ?? null;
    if (filePath && !state.insideRepo) {
        return { action: "skip" };
    }
    if (filePath && state.gitignored) {
        return { action: "skip" };
    }
    const sync = buildSyncPlan(state);
    if (state.inMerge) {
        return {
            action: "commit-merge",
            commit: buildMergeCommitPlan(input, state),
            sync,
        };
    }
    if (!filePath &&
        state.deletedFiles.length === 0 &&
        state.modifiedFiles.length === 0 &&
        state.untrackedFiles.length === 0) {
        return { action: "skip" };
    }
    const commit = buildCommitPlan(input, state);
    return { action: "commit-and-sync", commit, sync };
}
function buildMergeCommitPlan(input, state) {
    const changedPaths = changedPathsFor(input, state);
    const summary = state.relPath ?? (summarizeDeletions(changedPaths) || "resolved files");
    return {
        changedPaths,
        subject: `${buildSessionPrefix(input.session_id)}resolve merge conflict in ${summary}`,
        body: buildCommitBody(input, null),
    };
}
function buildSyncPlan(state) {
    if (!state.hasRemote)
        return null;
    return {
        currentBranch: state.currentBranch,
    };
}
function buildCommitPlan(input, state) {
    const filePath = input.tool_input.file_path ?? null;
    const changed = [...state.modifiedFiles, ...state.untrackedFiles];
    const changedPaths = changedPathsFor(input, state);
    let action;
    let relPath;
    if (filePath) {
        action = (input.tool_name ?? "update").toLowerCase();
        relPath = state.relPath;
    }
    else {
        action = changed.length === 0 ? "delete" : "update";
        relPath = summarizeDeletions([...changed, ...state.deletedFiles]);
    }
    const sessionPrefix = buildSessionPrefix(input.session_id);
    const subject = `${sessionPrefix}${action} ${relPath}`;
    const body = buildCommitBody(input, filePath ? relPath : null);
    return { changedPaths, subject, body };
}
function changedPathsFor(input, state) {
    if (input.tool_input.file_path)
        return [state.relPath];
    return [...state.modifiedFiles, ...state.untrackedFiles, ...state.deletedFiles];
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
    body += `\nAgent: ${agentForInput(input)}`;
    return body;
}
function agentForInput(input) {
    if (input.turn_id || input.tool_name === "apply_patch" || input.tool_name === "local_shell")
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
        return content.flatMap((item) => {
            if (typeof item === "string")
                return [item];
            if (typeof item !== "object" || item === null)
                return [];
            const block = item;
            return block.type === "text" && typeof block.text === "string" ? [block.text] : [];
        });
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
        if (/^<[^>]+>$/.test(trimmed))
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
