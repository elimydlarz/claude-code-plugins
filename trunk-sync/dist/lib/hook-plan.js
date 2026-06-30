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
    // No file_path and no deleted/modified files → nothing to do
    if (!filePath && state.deletedFiles.length === 0 && state.modifiedFiles.length === 0) {
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
    const filesToStage = filePath ? [filePath] : [...state.modifiedFiles];
    const filesToRemove = filePath ? [] : state.deletedFiles;
    let action;
    let relPath;
    if (filePath) {
        action = (input.tool_name ?? "update").toLowerCase();
        relPath = state.relPath;
    }
    else if (state.modifiedFiles.length > 0 && state.deletedFiles.length === 0) {
        action = "update";
        relPath = summarizeDeletions(state.modifiedFiles);
    }
    else if (state.deletedFiles.length > 0 && state.modifiedFiles.length === 0) {
        action = "delete";
        relPath = summarizeDeletions(state.deletedFiles);
    }
    else {
        action = "update";
        relPath = summarizeDeletions([...state.modifiedFiles, ...state.deletedFiles]);
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
        : summarizeDeletions([...state.modifiedFiles, ...state.deletedFiles]);
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
// --- Clocking in: agents clock in/out and see who else is working ---
/**
 * Build a clock-in plan for this agent's timecard.
 * Pure: needs runtime context (pid, hostname) passed in.
 * Task is populated later in the execute layer (requires transcript I/O).
 */
export function buildClockInPlan(input, state, runtime) {
    if (!input.session_id)
        return null;
    const now = new Date().toISOString();
    return {
        timecardPath: `.trunk-sync/timeclock/${input.session_id}.json`,
        timecard: {
            sessionId: input.session_id,
            pid: runtime.pid,
            hostname: runtime.hostname,
            clockedInAt: now,
            lastActiveAt: now,
            branch: state.currentBranch || "detached",
            task: null, // enriched in execute layer from transcript
            lastStep: null, // set by `trunk-sync progress`, preserved across clock-ins
            remainingSteps: null, // set by `trunk-sync progress`, preserved across clock-ins
        },
    };
}
/**
 * Classify timecards: who's still clocked in vs who should be clocked out.
 * Own session is excluded. Local agents with dead PIDs are clocked out.
 * Remote agents with old timestamps are clocked out.
 */
export function classifyTimecards(ownSessionId, timecards, now, localHostname, isLocalPidAlive, staleMinutes = 30) {
    const staleThreshold = staleMinutes * 60 * 1000;
    const clockedIn = [];
    const clockedOut = [];
    for (const tc of timecards) {
        if (tc.sessionId === ownSessionId)
            continue;
        const age = now.getTime() - new Date(tc.lastActiveAt).getTime();
        const isLocal = tc.hostname === localHostname;
        if (isLocal && !isLocalPidAlive(tc.pid)) {
            clockedOut.push(tc.sessionId);
        }
        else if (age > staleThreshold) {
            clockedOut.push(tc.sessionId);
        }
        else {
            clockedIn.push(tc);
        }
    }
    return { clockedIn, clockedOut };
}
/**
 * Format the message an agent sees when it clocks in.
 * Shows who else is working, and on the agent's first clock-in of the session
 * nudges it to run the tests — failing tests are checkpoints of unfinished WIP
 * left by an earlier agent, resumable when not owned by a still-clocked-in agent.
 * Returns null when there is nothing to say.
 */
export function formatClockInMessage(clockedIn, now, isFirstClockIn) {
    const sections = [];
    if (clockedIn.length > 0) {
        const lines = clockedIn.map((tc) => {
            const age = now.getTime() - new Date(tc.lastActiveAt).getTime();
            const agoStr = formatAge(age);
            const taskStr = tc.task ? ` — "${tc.task}"` : "";
            return `- ${tc.sessionId.slice(0, 8)} on ${tc.hostname} (branch: ${tc.branch}, ${agoStr} ago)${taskStr}`;
        });
        sections.push(`TRUNK-SYNC CLOCK-IN: ${clockedIn.length} other agent${clockedIn.length > 1 ? "s" : ""} clocked in. Continue your work as planned — no action required.`, ...lines);
    }
    if (isFirstClockIn) {
        sections.push("TRUNK-SYNC WIP: Run the test suite before starting. Failing tests are checkpoints marking where an earlier agent left off — any failing test that is not part of a still-clocked-in agent's work is unfinished WIP for you to resume.");
    }
    if (clockedIn.length > 0) {
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
/**
 * Format the handover roster shown at session start: every other clocked-in agent
 * with its branch, task, and agent-authored last step + remaining steps, so a starting
 * agent discovers work already in flight. Returns null when no other agents are clocked in.
 */
export function formatSessionStartSummary(clockedIn, now) {
    if (clockedIn.length === 0)
        return null;
    const lines = clockedIn.map((tc) => {
        const age = formatAge(now.getTime() - new Date(tc.lastActiveAt).getTime());
        let line = `- ${tc.sessionId.slice(0, 8)} on ${tc.hostname} (branch: ${tc.branch}, ${age} ago)`;
        if (tc.task)
            line += `\n    task: ${tc.task}`;
        if (tc.lastStep)
            line += `\n    last: ${tc.lastStep}`;
        if (tc.remainingSteps)
            line += `\n    next: ${tc.remainingSteps}`;
        return line;
    });
    return [
        `TRUNK-SYNC HANDOVER: ${clockedIn.length} other agent${clockedIn.length > 1 ? "s have" : " has"} work in progress:`,
        ...lines,
        "Resume any unfinished WIP above that is not owned by a still-clocked-in agent; coordinate on shared resources.",
    ].join("\n");
}
