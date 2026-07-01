import { describe, it } from "node:test";
import assert from "node:assert/strict";
import type { HookInput, RepoState, Timecard, RuntimeContext } from "./hook-types.js";
import {
  parseHookInput,
  planHook,
  buildCommitPlanWithTask,
  buildSessionPrefix,
  buildCommitBody,
  extractTaskFromTranscript,
  summarizeDeletions,
  buildClockInPlan,
  classifyTimecards,
  formatClockInMessage,
  formatSessionStartSummary,
} from "./hook-plan.js";

// ── Helpers ──────────────────────────────────────────────────────────

function makeInput(overrides: Partial<HookInput> = {}): HookInput {
  return {
    tool_name: "Write",
    tool_input: { file_path: "/repo/src/main.ts" },
    session_id: "abcdef12-3456-7890-abcd-ef1234567890",
    transcript_path: "~/.claude/projects/proj/session.jsonl",
    ...overrides,
  };
}

function makeState(overrides: Partial<RepoState> = {}): RepoState {
  return {
    repoRoot: "/repo",
    gitDir: "/repo/.git",
    relPath: "src/main.ts",
    insideRepo: true,
    gitignored: false,
    hasRemote: true,
    targetBranch: "main",
    currentBranch: "main",
    inMerge: false,
    hasStagedChanges: false,
    deletedFiles: [],
    modifiedFiles: [],
    ...overrides,
  };
}

// ── parseHookInput ───────────────────────────────────────────────────

describe("parseHookInput", () => {
  it("parses complete input", () => {
    const json = JSON.stringify({
      tool_name: "Edit",
      tool_input: { file_path: "/repo/file.ts" },
      session_id: "abc-123",
      transcript_path: "/path/to/transcript",
    });
    const result = parseHookInput(json);
    assert.equal(result.tool_name, "Edit");
    assert.equal(result.tool_input.file_path, "/repo/file.ts");
    assert.equal(result.session_id, "abc-123");
    assert.equal(result.transcript_path, "/path/to/transcript");
  });

  it("defaults missing fields to null", () => {
    const result = parseHookInput("{}");
    assert.equal(result.tool_name, null);
    assert.deepEqual(result.tool_input, {});
    assert.equal(result.session_id, null);
    assert.equal(result.transcript_path, null);
  });

  it("throws on invalid JSON", () => {
    assert.throws(() => parseHookInput("not json"));
  });
});

// ── planHook: skip conditions ────────────────────────────────────────

describe("planHook skip conditions", () => {
  it("skips when no file_path and no deletions and no modifications", () => {
    const input = makeInput({ tool_input: {} });
    const state = makeState({ deletedFiles: [], modifiedFiles: [] });
    const plan = planHook(input, state);
    assert.equal(plan.action, "skip");
  });

  it("skips when file is outside the repo", () => {
    const input = makeInput({ tool_input: { file_path: "/other/file.ts" } });
    const state = makeState({ insideRepo: false });
    const plan = planHook(input, state);
    assert.equal(plan.action, "skip");
  });

  it("skips when file is gitignored", () => {
    const input = makeInput();
    const state = makeState({ gitignored: true });
    const plan = planHook(input, state);
    assert.equal(plan.action, "skip");
  });
});

// ── planHook: merge state ────────────────────────────────────────────

describe("planHook merge state", () => {
  it("produces commit-merge with session prefix", () => {
    const input = makeInput();
    const state = makeState({ inMerge: true });
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-merge");
    if (plan.action !== "commit-merge") return;
    assert.equal(plan.message, "auto(abcdef12): resolve merge conflict in src/main.ts");
  });

  it("produces commit-merge without session prefix", () => {
    const input = makeInput({ session_id: null });
    const state = makeState({ inMerge: true });
    const plan = planHook(input, state);
    if (plan.action !== "commit-merge") return;
    assert.equal(plan.message, "auto: resolve merge conflict in src/main.ts");
  });

  it("includes sync plan when remote exists", () => {
    const input = makeInput();
    const state = makeState({ inMerge: true, hasRemote: true });
    const plan = planHook(input, state);
    if (plan.action !== "commit-merge") return;
    assert.deepEqual(plan.sync, { targetBranch: "main", currentBranch: "main" });
  });

  it("sync is null when no remote", () => {
    const input = makeInput();
    const state = makeState({ inMerge: true, hasRemote: false });
    const plan = planHook(input, state);
    if (plan.action !== "commit-merge") return;
    assert.equal(plan.sync, null);
  });
});

// ── planHook: normal commit ──────────────────────────────────────────

describe("planHook normal commit", () => {
  it("produces commit-and-sync for a file edit", () => {
    const input = makeInput();
    const state = makeState();
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    if (plan.action !== "commit-and-sync") return;
    assert.deepEqual(plan.commit.filesToStage, ["/repo/src/main.ts"]);
    assert.deepEqual(plan.commit.filesToRemove, []);
    assert.equal(plan.commit.subject, "auto(abcdef12): write src/main.ts");
    assert.equal(
      plan.commit.body,
      "Session: abcdef12-3456-7890-abcd-ef1234567890\nAgent: claude\nTranscriptPath: ~/.claude/projects/proj/session.jsonl",
    );
  });

  it("uses tool_name in subject", () => {
    const input = makeInput({ tool_name: "Edit" });
    const state = makeState();
    const plan = planHook(input, state);
    if (plan.action !== "commit-and-sync") return;
    assert.match(plan.commit.subject, /^auto\(abcdef12\): edit src\/main\.ts$/);
  });

  it("defaults tool_name to 'update'", () => {
    const input = makeInput({ tool_name: null });
    const state = makeState();
    const plan = planHook(input, state);
    if (plan.action !== "commit-and-sync") return;
    assert.match(plan.commit.subject, /update src\/main\.ts/);
  });

  it("handles deletion path", () => {
    const input = makeInput({ tool_input: {} });
    const state = makeState({
      deletedFiles: ["old.ts", "stale.ts", "gone.ts"],
      relPath: null,
    });
    const plan = planHook(input, state);
    if (plan.action !== "commit-and-sync") return;
    assert.deepEqual(plan.commit.filesToStage, []);
    assert.deepEqual(plan.commit.filesToRemove, ["old.ts", "stale.ts", "gone.ts"]);
    assert.match(plan.commit.subject, /delete old\.ts \(\+2 more\)/);
  });

  it("handles modified files (e.g. permission changes) when no file_path", () => {
    const input = makeInput({ tool_input: {} });
    const state = makeState({
      modifiedFiles: ["script.sh"],
      relPath: null,
    });
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    if (plan.action !== "commit-and-sync") return;
    assert.deepEqual(plan.commit.filesToStage, ["script.sh"]);
    assert.deepEqual(plan.commit.filesToRemove, []);
    assert.match(plan.commit.subject, /update script\.sh/);
  });

  it("handles both deletions and modifications together", () => {
    const input = makeInput({ tool_input: {} });
    const state = makeState({
      deletedFiles: ["gone.ts"],
      modifiedFiles: ["changed.sh"],
      relPath: null,
    });
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    if (plan.action !== "commit-and-sync") return;
    assert.deepEqual(plan.commit.filesToStage, ["changed.sh"]);
    assert.deepEqual(plan.commit.filesToRemove, ["gone.ts"]);
  });

  it("sync is null when no remote", () => {
    const input = makeInput();
    const state = makeState({ hasRemote: false });
    const plan = planHook(input, state);
    if (plan.action !== "commit-and-sync") return;
    assert.equal(plan.sync, null);
  });

  it("includes sync plan on worktree branch", () => {
    const input = makeInput();
    const state = makeState({ currentBranch: "trunk-sync-abc" });
    const plan = planHook(input, state);
    if (plan.action !== "commit-and-sync") return;
    assert.deepEqual(plan.sync, { targetBranch: "main", currentBranch: "trunk-sync-abc" });
  });

  it("body is null when no session or transcript", () => {
    const input = makeInput({ session_id: null, transcript_path: null });
    const state = makeState();
    const plan = planHook(input, state);
    if (plan.action !== "commit-and-sync") return;
    assert.equal(plan.commit.body, null);
  });

  it("Codex apply_patch with no file_path stages dirty tracked files", () => {
    const input = makeInput({
      tool_name: "apply_patch",
      tool_input: { input: "*** Begin Patch\n*** Update File: foo.ts\n*** End Patch\n" } as unknown as { file_path?: string },
    });
    const state = makeState({ modifiedFiles: ["foo.ts"], relPath: null });
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    if (plan.action !== "commit-and-sync") return;
    assert.deepEqual(plan.commit.filesToStage, ["foo.ts"]);
    assert.match(plan.commit.subject, /update foo\.ts/);
  });

  it("Codex local_shell with no file_path stages dirty tracked files", () => {
    const input = makeInput({
      tool_name: "local_shell",
      tool_input: { command: ["sed", "-i", "s/x/y/", "foo.ts"] } as unknown as { file_path?: string },
    });
    const state = makeState({ modifiedFiles: ["foo.ts"], relPath: null });
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    if (plan.action !== "commit-and-sync") return;
    assert.deepEqual(plan.commit.filesToStage, ["foo.ts"]);
  });

  it("includes TranscriptPath in body when transcript_path is in payload", () => {
    const input = makeInput({
      tool_name: "apply_patch",
      tool_input: {} as { file_path?: string },
      session_id: "abc12345-6789-0abc-def0-123456789abc",
      transcript_path: "/codex/sessions/abc12345.jsonl",
    });
    const state = makeState({ modifiedFiles: ["foo.ts"], relPath: null });
    const plan = planHook(input, state);
    if (plan.action !== "commit-and-sync") return;
    assert.match(plan.commit.body ?? "", /Session: abc12345-6789-0abc-def0-123456789abc/);
    assert.match(plan.commit.body ?? "", /TranscriptPath: \/codex\/sessions\/abc12345\.jsonl/);
  });

  it("omits TranscriptPath when transcript_path is absent", () => {
    const input = makeInput({ transcript_path: null });
    const state = makeState();
    const plan = planHook(input, state);
    if (plan.action !== "commit-and-sync") return;
    assert.doesNotMatch(plan.commit.body ?? "", /TranscriptPath:/);
  });
});

// ── buildCommitPlanWithTask ──────────────────────────────────────────

describe("buildCommitPlanWithTask", () => {
  it("uses task as subject when provided", () => {
    const input = makeInput();
    const state = makeState();
    const commit = buildCommitPlanWithTask(input, state, "Fix the broken tests");
    assert.equal(commit.subject, "auto(abcdef12): Fix the broken tests");
    assert.match(commit.body!, /^File: src\/main\.ts/);
    assert.match(commit.body!, /Session: abcdef12/);
    assert.match(commit.body!, /TranscriptPath: ~\/\.claude\/projects\/proj\/session\.jsonl/);
  });

  it("falls back to default plan when task is null", () => {
    const input = makeInput();
    const state = makeState();
    const commit = buildCommitPlanWithTask(input, state, null);
    assert.match(commit.subject, /write src\/main\.ts/);
  });
});

// ── buildSessionPrefix ──────────────────────────────────────────────

describe("buildSessionPrefix", () => {
  it("includes short session id", () => {
    assert.equal(buildSessionPrefix("abcdef1234567890"), "auto(abcdef12): ");
  });

  it("returns plain auto: when null", () => {
    assert.equal(buildSessionPrefix(null), "auto: ");
  });
});

// ── buildCommitBody ──────────────────────────────────────────────────

describe("buildCommitBody", () => {
  it("includes session and transcript path", () => {
    const input = makeInput();
    const body = buildCommitBody(input, "src/main.ts");
    assert.equal(
      body,
      "Session: abcdef12-3456-7890-abcd-ef1234567890\nAgent: claude\nTranscriptPath: ~/.claude/projects/proj/session.jsonl",
    );
  });

  it("includes session only when transcript_path is absent", () => {
    const input = makeInput({ transcript_path: null });
    const body = buildCommitBody(input, "src/main.ts");
    assert.equal(body, "Session: abcdef12-3456-7890-abcd-ef1234567890\nAgent: claude");
  });

  it("returns null when no session", () => {
    const input = makeInput({ session_id: null });
    assert.equal(buildCommitBody(input, "src/main.ts"), null);
  });

  it("includes Agent: claude when tool is Claude's Edit/Write/Bash", () => {
    for (const tool_name of ["Edit", "Write", "Bash"]) {
      const body = buildCommitBody(makeInput({ tool_name }), "src/main.ts");
      assert.match(body ?? "", /^Agent: claude$/m, `tool ${tool_name}`);
    }
  });

  it("includes Agent: codex when tool is Codex's apply_patch/local_shell", () => {
    for (const tool_name of ["apply_patch", "local_shell"]) {
      const body = buildCommitBody(makeInput({ tool_name }), "src/main.ts");
      assert.match(body ?? "", /^Agent: codex$/m, `tool ${tool_name}`);
    }
  });
});

// ── extractTaskFromTranscript ────────────────────────────────────────

describe("extractTaskFromTranscript", () => {
  it("extracts first user message", () => {
    const content = jsonl({ type: "user", message: { role: "user", content: "Fix the login bug" } });
    assert.equal(extractTaskFromTranscript(content), "Fix the login bug");
  });

  it("skips hook feedback lines", () => {
    const content = jsonl({
      type: "user",
      message: { role: "user", content: "Stop hook feedback: some error" },
    });
    assert.equal(extractTaskFromTranscript(content), null);
  });

  it("skips 'Implement the following plan:' header", () => {
    const content = jsonl({
      type: "user",
      message: { role: "user", content: "Implement the following plan:\n\nDo the thing" },
    });
    assert.equal(extractTaskFromTranscript(content), "Do the thing");
  });

  it("skips XML tags", () => {
    const content = jsonl({
      type: "user",
      message: { role: "user", content: "<context>\nActual task" },
    });
    assert.equal(extractTaskFromTranscript(content), "Actual task");
  });

  it("strips markdown headers", () => {
    const content = jsonl({
      type: "user",
      message: { role: "user", content: "## My Feature Request" },
    });
    assert.equal(extractTaskFromTranscript(content), "My Feature Request");
  });

  it("truncates at 72 chars", () => {
    const longMsg = "A".repeat(100);
    const content = jsonl({ type: "user", message: { role: "user", content: longMsg } });
    assert.equal(extractTaskFromTranscript(content)!.length, 72);
  });

  it("handles array content", () => {
    const content = jsonl({
      type: "user",
      message: { role: "user", content: ["First part", "Second part"] },
    });
    assert.equal(extractTaskFromTranscript(content), "First part");
  });

  it("skips non-user messages", () => {
    const content = jsonl({ type: "assistant", message: { role: "assistant", content: "Sure" } });
    assert.equal(extractTaskFromTranscript(content), null);
  });

  it("returns null for empty content", () => {
    assert.equal(extractTaskFromTranscript(""), null);
  });

  it("handles invalid JSON lines gracefully", () => {
    const content = "not json\n" + jsonl({
      type: "user",
      message: { role: "user", content: "Real task" },
    });
    assert.equal(extractTaskFromTranscript(content), "Real task");
  });

});

// ── summarizeDeletions ───────────────────────────────────────────────

describe("summarizeDeletions", () => {
  it("returns empty for no files", () => {
    assert.equal(summarizeDeletions([]), "");
  });

  it("returns filename for single file", () => {
    assert.equal(summarizeDeletions(["file.ts"]), "file.ts");
  });

  it("summarizes multiple files", () => {
    assert.equal(summarizeDeletions(["a.ts", "b.ts", "c.ts"]), "a.ts (+2 more)");
  });
});

// ── buildClockInPlan ─────────────────────────────────────────────────

const runtime: RuntimeContext = { hostname: "my-macbook" };

describe("buildClockInPlan", () => {
  it("returns clock-in plan with timecard path", () => {
    const input = makeInput();
    const state = makeState();
    const plan = buildClockInPlan(input, state, runtime);
    assert.notEqual(plan, null);
    assert.equal(plan!.timecardPath, ".trunk-sync/timeclock/abcdef12-3456-7890-abcd-ef1234567890.json");
    assert.equal(plan!.timecard.sessionId, "abcdef12-3456-7890-abcd-ef1234567890");
    assert.equal(plan!.timecard.hostname, "my-macbook");
    assert.equal(plan!.timecard.branch, "main");
    assert.equal(plan!.timecard.task, null);
  });

  it("returns null when session_id is null", () => {
    const input = makeInput({ session_id: null });
    const state = makeState();
    assert.equal(buildClockInPlan(input, state, runtime), null);
  });

  it("uses 'detached' when currentBranch is empty", () => {
    const input = makeInput();
    const state = makeState({ currentBranch: "" });
    const plan = buildClockInPlan(input, state, runtime);
    assert.equal(plan!.timecard.branch, "detached");
  });
});

// ── planHook clock-in plan ───────────────────────────────────────────

describe("planHook clock-in plan", () => {
  it("includes clock-in plan when runtime context provided", () => {
    const input = makeInput();
    const state = makeState();
    const plan = planHook(input, state, runtime);
    if (plan.action !== "commit-and-sync") return;
    assert.notEqual(plan.clockIn, null);
    assert.equal(plan.clockIn!.timecard.hostname, "my-macbook");
  });

  it("clockIn is null without runtime context", () => {
    const input = makeInput();
    const state = makeState();
    const plan = planHook(input, state);
    if (plan.action !== "commit-and-sync") return;
    assert.equal(plan.clockIn, null);
  });

  it("includes clock-in plan on commit-merge", () => {
    const input = makeInput();
    const state = makeState({ inMerge: true });
    const plan = planHook(input, state, runtime);
    if (plan.action !== "commit-merge") return;
    assert.notEqual(plan.clockIn, null);
  });
});

// ── classifyTimecards ───────────────────────────────────────────────────

describe("classifyTimecards", () => {
  const now = new Date("2026-03-27T10:05:00.000Z");

  function makeTimecard(overrides: Partial<Timecard> = {}): Timecard {
    return {
      sessionId: "other-session-id",
      pid: 99999,
      hostname: "my-macbook",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:04:00.000Z",
      branch: "main",
      task: null,
      lastStep: null,
      remainingSteps: null,
      ...overrides,
    };
  }

  it("excludes own session from both lists", () => {
    const timecards = [makeTimecard({ sessionId: "my-session" })];
    const result = classifyTimecards("my-session", timecards, now, "my-macbook", () => true);
    assert.equal(result.clockedIn.length, 0);
    assert.equal(result.clockedOut.length, 0);
  });

  it("clocks out local agent with dead PID", () => {
    const timecards = [makeTimecard({ hostname: "my-macbook", pid: 99999 })];
    const result = classifyTimecards("my-session", timecards, now, "my-macbook", () => false);
    assert.equal(result.clockedOut.length, 1);
    assert.equal(result.clockedIn.length, 0);
  });

  it("keeps local agent with live PID clocked in", () => {
    const timecards = [makeTimecard({ hostname: "my-macbook", pid: 99999 })];
    const result = classifyTimecards("my-session", timecards, now, "my-macbook", () => true);
    assert.equal(result.clockedIn.length, 1);
    assert.equal(result.clockedOut.length, 0);
  });

  it("clocks out remote agent with old timestamp", () => {
    const timecards = [makeTimecard({
      hostname: "other-machine",
      lastActiveAt: "2026-03-27T09:30:00.000Z", // 35 min ago
    })];
    const result = classifyTimecards("my-session", timecards, now, "my-macbook", () => true);
    assert.equal(result.clockedOut.length, 1);
    assert.equal(result.clockedIn.length, 0);
  });

  it("keeps remote agent with recent timestamp clocked in", () => {
    const timecards = [makeTimecard({
      hostname: "other-machine",
      lastActiveAt: "2026-03-27T10:03:00.000Z", // 2 min ago
    })];
    const result = classifyTimecards("my-session", timecards, now, "my-macbook", () => true);
    assert.equal(result.clockedIn.length, 1);
    assert.equal(result.clockedOut.length, 0);
  });

  it("handles mix of clocked-in and clocked-out agents", () => {
    const timecards = [
      makeTimecard({ sessionId: "active-1", hostname: "other", lastActiveAt: "2026-03-27T10:04:00.000Z" }),
      makeTimecard({ sessionId: "stale-1", hostname: "other", lastActiveAt: "2026-03-27T09:30:00.000Z" }),
      makeTimecard({ sessionId: "stale-local", hostname: "my-macbook", pid: 11111 }),
    ];
    const result = classifyTimecards("my-session", timecards, now, "my-macbook", (pid) => pid !== 11111);
    assert.equal(result.clockedIn.length, 1);
    assert.equal(result.clockedIn[0].sessionId, "active-1");
    assert.equal(result.clockedOut.length, 2);
  });
});

// ── formatClockInMessage ──────────────────────────────────────────────

describe("formatClockInMessage", () => {
  const now = new Date("2026-03-27T10:05:00.000Z");

  it("returns null when no other agents are clocked in and this is not the first clock-in", () => {
    assert.equal(formatClockInMessage([], now, false), null);
  });

  it("formats single agent without task", () => {
    const timecards: Timecard[] = [{
      sessionId: "abcdef12-3456-7890-abcd-ef1234567890",
      pid: 123, hostname: "my-macbook",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:04:30.000Z",
      branch: "main", task: null,
      lastStep: null, remainingSteps: null,
    }];
    const msg = formatClockInMessage(timecards, now, false)!;
    assert.match(msg, /1 other agent clocked in/);
    assert.match(msg, /abcdef12 on my-macbook/);
    assert.match(msg, /branch: main/);
    assert.match(msg, /30s ago/);
    assert.match(msg, /no action required/);
    assert.match(msg, /share resources/);
  });

  it("includes task description when present", () => {
    const timecards: Timecard[] = [{
      sessionId: "abcdef12-3456-7890-abcd-ef1234567890",
      pid: 123, hostname: "my-macbook",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:04:30.000Z",
      branch: "main", task: "Fix the login bug",
      lastStep: null, remainingSteps: null,
    }];
    const msg = formatClockInMessage(timecards, now, false)!;
    assert.match(msg, /"Fix the login bug"/);
  });

  it("formats multiple agents", () => {
    const timecards: Timecard[] = [
      {
        sessionId: "aaaa0000-0000-0000-0000-000000000000",
        pid: 1, hostname: "mac-1", clockedInAt: "2026-03-27T10:00:00.000Z",
        lastActiveAt: "2026-03-27T10:04:00.000Z", branch: "main", task: "Add tests",
        lastStep: null, remainingSteps: null,
      },
      {
        sessionId: "bbbb0000-0000-0000-0000-000000000000",
        pid: 2, hostname: "mac-2", clockedInAt: "2026-03-27T10:00:00.000Z",
        lastActiveAt: "2026-03-27T10:02:00.000Z", branch: "feature", task: null,
        lastStep: null, remainingSteps: null,
      },
    ];
    const msg = formatClockInMessage(timecards, now, false)!;
    assert.match(msg, /2 other agents clocked in/);
    assert.match(msg, /aaaa0000 on mac-1/);
    assert.match(msg, /bbbb0000 on mac-2/);
    assert.match(msg, /"Add tests"/);
  });

  it("formats minutes correctly", () => {
    const timecards: Timecard[] = [{
      sessionId: "abcdef12-0000-0000-0000-000000000000",
      pid: 1, hostname: "h", clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:02:00.000Z", branch: "main", task: null,
      lastStep: null, remainingSteps: null,
    }];
    const msg = formatClockInMessage(timecards, now, false)!;
    assert.match(msg, /3m ago/);
  });

  it("nudges the agent to run the tests and resume WIP on the first clock-in", () => {
    const msg = formatClockInMessage([], now, true)!;
    assert.match(msg, /TRUNK-SYNC WIP/);
    assert.match(msg, /Run the test suite/);
    assert.match(msg, /checkpoints/);
    assert.match(msg, /resume/);
    assert.match(msg, /still-clocked-in agent's work/);
  });

  it("includes both the clocked-in roster and the run-tests nudge on the first clock-in with others present", () => {
    const timecards: Timecard[] = [{
      sessionId: "abcdef12-3456-7890-abcd-ef1234567890",
      pid: 123, hostname: "my-macbook",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:04:30.000Z",
      branch: "main", task: "Refactoring auth",
      lastStep: null, remainingSteps: null,
    }];
    const msg = formatClockInMessage(timecards, now, true)!;
    assert.match(msg, /1 other agent clocked in/);
    assert.match(msg, /"Refactoring auth"/);
    assert.match(msg, /TRUNK-SYNC WIP/);
    assert.match(msg, /Run the test suite/);
  });
});

describe("formatSessionStartSummary", () => {
  const now = new Date("2026-03-27T10:05:00.000Z");

  function card(overrides: Partial<Timecard> = {}): Timecard {
    return {
      sessionId: "aaaa0000-0000-0000-0000-000000000000",
      pid: 1, hostname: "mac-1",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:04:00.000Z",
      branch: "main", task: null, lastStep: null, remainingSteps: null,
      ...overrides,
    };
  }

  it("returns null when no other timecards are clocked in", () => {
    assert.equal(formatSessionStartSummary([], now), null);
  });

  it("lists branch, task, last step, and remaining steps for an agent with progress", () => {
    const msg = formatSessionStartSummary([card({
      task: "Add handover", lastStep: "wired the CLI", remainingSteps: "add the functional test",
    })], now)!;
    assert.match(msg, /aaaa0000 on mac-1/);
    assert.match(msg, /branch: main/);
    assert.match(msg, /task: Add handover/);
    assert.match(msg, /last: wired the CLI/);
    assert.match(msg, /next: add the functional test/);
    assert.match(msg, /Resume any unfinished WIP/);
  });

  it("shows the task without progress fields when none is recorded", () => {
    const msg = formatSessionStartSummary([card({ task: "Some task" })], now)!;
    assert.match(msg, /task: Some task/);
    assert.doesNotMatch(msg, /last:/);
    assert.doesNotMatch(msg, /next:/);
  });

  it("lists multiple agents", () => {
    const msg = formatSessionStartSummary([
      card({ sessionId: "aaaa0000-0000-0000-0000-000000000000", hostname: "mac-1" }),
      card({ sessionId: "bbbb0000-0000-0000-0000-000000000000", hostname: "mac-2" }),
    ], now)!;
    assert.match(msg, /2 other sessions have work in progress/);
    assert.match(msg, /aaaa0000 on mac-1/);
    assert.match(msg, /bbbb0000 on mac-2/);
  });
});

// ── Helper ───────────────────────────────────────────────────────────

function jsonl(...objects: unknown[]): string {
  return objects.map((o) => JSON.stringify(o)).join("\n");
}
