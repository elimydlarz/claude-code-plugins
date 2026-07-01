import type {
  HookInput,
  RepoState,
  HookPlan,
  CommitPlan,
  SyncPlan,
  ClockInPlan,
  Timecard,
  RuntimeContext,
} from "./hook-types.js";

/**
 * Parse the raw JSON string from hook stdin into a typed HookInput.
 */
export function parseHookInput(json: string): HookInput {
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
export function planHook(input: HookInput, state: RepoState, runtime?: RuntimeContext): HookPlan {
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
    const relPath = filePath ? state.relPath! : summarizeDeletions(state.deletedFiles);
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

function buildSyncPlan(state: RepoState): SyncPlan | null {
  if (!state.hasRemote) return null;
  return {
    targetBranch: state.targetBranch,
    currentBranch: state.currentBranch,
  };
}

function buildCommitPlan(input: HookInput, state: RepoState): CommitPlan {
  const filePath = input.tool_input.file_path ?? null;

  const filesToStage = filePath ? [filePath] : [...state.modifiedFiles];
  const filesToRemove = filePath ? [] : state.deletedFiles;

  let action: string;
  let relPath: string;

  if (filePath) {
    action = (input.tool_name ?? "update").toLowerCase();
    relPath = state.relPath!;
  } else if (state.modifiedFiles.length > 0 && state.deletedFiles.length === 0) {
    action = "update";
    relPath = summarizeDeletions(state.modifiedFiles);
  } else if (state.deletedFiles.length > 0 && state.modifiedFiles.length === 0) {
    action = "delete";
    relPath = summarizeDeletions(state.deletedFiles);
  } else {
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
export function buildCommitPlanWithTask(
  input: HookInput,
  state: RepoState,
  task: string | null,
): CommitPlan {
  const base = buildCommitPlan(input, state);
  if (!task) return base;

  const filePath = input.tool_input.file_path ?? null;
  const relPath = filePath
    ? state.relPath!
    : summarizeDeletions([...state.modifiedFiles, ...state.deletedFiles]);
  const sessionPrefix = buildSessionPrefix(input.session_id);
  const subject = `${sessionPrefix}${task}`;

  // When task is present, include File: line in body
  let body = `File: ${relPath}`;
  if (input.session_id) body += `\nSession: ${input.session_id}`;
  if (input.transcript_path) body += `\nTranscriptPath: ${input.transcript_path}`;

  return { ...base, subject, body: body || null };
}

export function buildSessionPrefix(sessionId: string | null): string {
  if (sessionId) return `auto(${sessionId.slice(0, 8)}): `;
  return "auto: ";
}

export function buildCommitBody(
  input: HookInput,
  _relPath: string | null,
): string | null {
  if (!input.session_id) return null;
  let body = `Session: ${input.session_id}`;
  body += `\nAgent: ${agentForTool(input.tool_name)}`;
  if (input.transcript_path) body += `\nTranscriptPath: ${input.transcript_path}`;
  return body;
}

function agentForTool(toolName: string | null): "claude" | "codex" {
  if (toolName === "apply_patch" || toolName === "local_shell") return "codex";
  return "claude";
}

/**
 * Extract the first user message from a JSONL transcript.
 * Filters out hook feedback, plan headers, XML tags, and empty lines.
 * Returns first 72 chars or null.
 */
export function extractTaskFromTranscript(content: string): string | null {
  const lines = content.split("\n");
  for (const line of lines) {
    if (!line.trim()) continue;
    let parsed: unknown;
    try {
      parsed = JSON.parse(line);
    } catch {
      continue;
    }
    if (!isUserMessage(parsed)) continue;
    const msg = (parsed as { message: { content: unknown } }).message;
    const texts = extractTextContent(msg.content);
    for (const text of texts) {
      const candidate = filterTaskLine(text);
      if (candidate) return candidate.slice(0, 72);
    }
  }
  return null;
}

function isUserMessage(obj: unknown): boolean {
  if (typeof obj !== "object" || obj === null) return false;
  const rec = obj as Record<string, unknown>;
  if (rec.type !== "user") return false;
  if (typeof rec.message !== "object" || rec.message === null) return false;
  const msg = rec.message as Record<string, unknown>;
  return msg.role === "user";
}

function extractTextContent(content: unknown): string[] {
  if (typeof content === "string") return [content];
  if (Array.isArray(content)) {
    return content.filter((item): item is string => typeof item === "string");
  }
  return [];
}

function filterTaskLine(text: string): string | null {
  const lines = text.split("\n");
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    if (trimmed.startsWith("Stop hook feedback:")) return null;
    if (trimmed === "Implement the following plan:") continue;
    if (trimmed.startsWith("<")) continue;
    // Strip leading markdown headers
    const stripped = trimmed.replace(/^#{1,}\s+/, "");
    if (stripped) return stripped;
  }
  return null;
}

/**
 * Summarize a list of deleted files: "file.txt (+2 more)"
 */
export function summarizeDeletions(files: string[]): string {
  if (files.length === 0) return "";
  const first = files[0];
  if (files.length === 1) return first;
  return `${first} (+${files.length - 1} more)`;
}

// --- Clocking in: agents clock in/out and see who else is working ---

/**
 * Build a clock-in plan for this agent's timecard.
 * Pure: needs runtime context (pid, hostname) passed in.
 * Task is populated later in the execute layer (requires transcript I/O).
 */
export function buildClockInPlan(
  input: HookInput,
  state: RepoState,
  runtime: RuntimeContext,
): ClockInPlan | null {
  if (!input.session_id) return null;
  const now = new Date().toISOString();
  return {
    timecardPath: `.trunk-sync/timeclock/${input.session_id}.json`,
    timecard: {
      sessionId: input.session_id,
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

/** Recent heartbeat ⇒ the agent is active (coordinate, don't duplicate). */
export const DISPLAY_WINDOW_MS = 60 * 60 * 1000; // 60 minutes
/** Heartbeat older than this ⇒ the card is abandoned and swept (the transcript is the record). */
export const REAP_TTL_MS = 14 * 24 * 60 * 60 * 1000; // 14 days

/**
 * Classify timecards purely by heartbeat age — one uniform rule for every card,
 * no PID and no local/remote split (a stored PID is the ephemeral hook process,
 * never the agent). Own session excluded.
 *  - within the display window        → active (recently alive)
 *  - past the window, within the TTL   → stale (possibly disrupted; surfaced to resume)
 *  - past the TTL                      → reapable (even with unfinished steps; the transcript remains)
 */
export function classifyTimecards(
  ownSessionId: string | null,
  timecards: Timecard[],
  now: Date,
): { active: Timecard[]; stale: Timecard[]; reapable: Timecard[] } {
  const active: Timecard[] = [];
  const stale: Timecard[] = [];
  const reapable: Timecard[] = [];

  for (const tc of timecards) {
    if (tc.sessionId === ownSessionId) continue;

    const age = now.getTime() - new Date(tc.lastActiveAt).getTime();
    if (age <= DISPLAY_WINDOW_MS) active.push(tc);
    else if (age <= REAP_TTL_MS) stale.push(tc);
    else reapable.push(tc);
  }

  return { active, stale, reapable };
}

/**
 * Format the message an agent sees when it clocks in.
 * Shows who else is working, and on the agent's first clock-in of the session
 * nudges it to run the tests — failing tests are checkpoints of unfinished WIP
 * left by an earlier agent, resumable when not owned by a still-clocked-in agent.
 * Returns null when there is nothing to say.
 */
export function formatClockInMessage(
  clockedIn: Timecard[],
  now: Date,
  isFirstClockIn: boolean,
): string | null {
  const sections: string[] = [];

  if (clockedIn.length > 0) {
    const lines = clockedIn.map((tc) => {
      const age = now.getTime() - new Date(tc.lastActiveAt).getTime();
      const agoStr = formatAge(age);
      const taskStr = tc.task ? ` — "${tc.task}"` : "";
      return `- ${tc.sessionId.slice(0, 8)} on ${tc.hostname} (branch: ${tc.branch}, ${agoStr} ago)${taskStr}`;
    });
    sections.push(
      `TRUNK-SYNC CLOCK-IN: ${clockedIn.length} other agent${clockedIn.length > 1 ? "s" : ""} clocked in. Continue your work as planned — no action required.`,
      ...lines,
    );
  }

  if (isFirstClockIn) {
    sections.push(
      "TRUNK-SYNC WIP: Run the test suite before starting. Failing tests are checkpoints marking where an earlier agent left off — any failing test that is not part of a still-clocked-in agent's work is unfinished WIP for you to resume.",
    );
  }

  if (clockedIn.length > 0) {
    sections.push(
      "If you share resources (ports, test databases, build locks), coordinate accordingly. Otherwise, ignore this message.",
    );
  }

  if (sections.length === 0) return null;
  return sections.join("\n");
}

function formatAge(ms: number): string {
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  return `${hours}h`;
}

/**
 * Format the handover roster shown at session start: every other clocked-in agent
 * with its branch, task, and agent-authored last step + remaining steps, so a starting
 * agent discovers work already in flight. Returns null when no other agents are clocked in.
 */
export function formatSessionStartSummary(sessions: Timecard[], now: Date): string | null {
  if (sessions.length === 0) return null;
  const lines = sessions.map((tc) => {
    const age = formatAge(now.getTime() - new Date(tc.lastActiveAt).getTime());
    let line = `- ${tc.sessionId.slice(0, 8)} on ${tc.hostname} (branch: ${tc.branch}, ${age} ago)`;
    if (tc.task) line += `\n    task: ${tc.task}`;
    if (tc.lastStep) line += `\n    last: ${tc.lastStep}`;
    if (tc.remainingSteps) line += `\n    next: ${tc.remainingSteps}`;
    return line;
  });
  return [
    `TRUNK-SYNC HANDOVER: ${sessions.length} other session${sessions.length > 1 ? "s have" : " has"} work in progress:`,
    ...lines,
    "Resume any unfinished WIP above; if another agent is still actively working it, coordinate rather than duplicate.",
  ].join("\n");
}
