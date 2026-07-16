import { describe, it } from "node:test";
import assert from "node:assert/strict";
import type { HookInput, RepoState, Timecard } from "./hook-types.js";
import {
  parseHookInput,
  planHook,
  buildCommitPlanWithTask,
  buildSessionPrefix,
  buildCommitBody,
  extractTaskFromTranscript,
  summarizeDeletions,
  classifyTimecards,
  formatClockInMessage,
  formatSessionStartSummary,
} from "./hook-plan.js";


function makeInput(overrides: Partial<HookInput> = {}): HookInput {
  return {
    tool_name: "Write",
    tool_input: { file_path: "/repo/src/main.ts" },
    turn_id: null,
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
    currentBranch: "main",
    inMerge: false,
    deletedFiles: [],
    modifiedFiles: [],
    untrackedFiles: [],
    ...overrides,
  };
}


describe("parseHookInput", () => {
  it("parses complete input", () => {
    const json = JSON.stringify({
      tool_name: "Edit",
      tool_input: { file_path: "/repo/file.ts" },
      turn_id: "turn-123",
      session_id: "abc-123",
      transcript_path: "/path/to/transcript",
      cwd: "/repo",
    });
    const result = parseHookInput(json);
    assert.equal(result.tool_name, "Edit");
    assert.equal(result.tool_input.file_path, "/repo/file.ts");
    assert.equal(result.turn_id, "turn-123");
    assert.equal(result.session_id, "abc-123");
    assert.equal(result.transcript_path, "/path/to/transcript");
    assert.equal(result.cwd, "/repo");
  });

  it("defaults missing fields to null", () => {
    const result = parseHookInput("{}");
    assert.equal(result.tool_name, null);
    assert.deepEqual(result.tool_input, {});
    assert.equal(result.turn_id, null);
    assert.equal(result.session_id, null);
    assert.equal(result.transcript_path, null);
    assert.equal(result.cwd, null);

    const explicitNulls = parseHookInput(JSON.stringify({
      tool_name: null,
      tool_input: null,
      turn_id: null,
      session_id: null,
      transcript_path: null,
      cwd: null,
    }));
    assert.deepEqual(explicitNulls, result);
  });

  it("throws on invalid or non-object JSON", () => {
    for (const input of [
      "not json",
      "42",
      "[]",
      JSON.stringify({ session_id: 42 }),
      JSON.stringify({ tool_input: 42 }),
      JSON.stringify({ tool_input: { file_path: 42 } }),
    ]) assert.throws(() => parseHookInput(input));
  });
});


describe("planHook skip conditions", () => {
  it("skips when no file_path and no deleted, modified, or untracked files", () => {
    const input = makeInput({ tool_input: {} });
    const state = makeState({ deletedFiles: [], modifiedFiles: [], untrackedFiles: [] });
    const plan = planHook(input, state);
    assert.equal(plan.action, "skip");
  });

  it("skips when file is outside the repo", () => {
    const input = makeInput({ tool_input: { file_path: "/other/file.ts" } });
    for (const inMerge of [false, true]) {
      const state = makeState({ insideRepo: false, inMerge });
      const plan = planHook(input, state);
      assert.equal(plan.action, "skip");
    }
  });

  it("skips when file is gitignored", () => {
    const input = makeInput();
    for (const inMerge of [false, true]) {
      const state = makeState({ gitignored: true, inMerge });
      const plan = planHook(input, state);
      assert.equal(plan.action, "skip");
    }
  });
});


describe("planHook merge state", () => {
  describe("while a merge is in progress", () => {
    it("produces commit-merge with session prefix and provenance", () => {
      const input = makeInput();
      const state = makeState({ inMerge: true });
      const plan = planHook(input, state);
      assert.equal(plan.action, "commit-merge");
      assert.equal(plan.commit.subject, "auto(abcdef12): resolve merge conflict in src/main.ts");
      assert.equal(plan.commit.body, "Session: abcdef12-3456-7890-abcd-ef1234567890\nAgent: claude");
    });

    it("produces commit-merge without session prefix", () => {
      const input = makeInput({ session_id: null });
      const state = makeState({ inMerge: true });
      const plan = planHook(input, state);
      assert.equal(plan.action, "commit-merge");
      assert.equal(plan.commit.subject, "auto: resolve merge conflict in src/main.ts");
    });

    it("includes every detected resolved path for Codex merge recovery", () => {
      const input = makeInput({
        tool_name: "apply_patch",
        tool_input: { input: "patch" } as unknown as { file_path?: string },
      });
      const state = makeState({
        inMerge: true,
        relPath: null,
        modifiedFiles: ["resolved.txt"],
        untrackedFiles: ["new.txt"],
        deletedFiles: ["deleted.txt"],
      });

      const plan = planHook(input, state);

      assert.equal(plan.action, "commit-merge");
      assert.deepEqual(plan.commit.changedPaths, ["resolved.txt", "new.txt", "deleted.txt"]);
      assert.match(plan.commit.body ?? "", /^Agent: codex$/m);
    });

    it("summarizes detected resolved paths when no file_path is available", () => {
      const input = makeInput({ tool_name: "apply_patch", tool_input: {} });
      const state = makeState({ inMerge: true, relPath: null, modifiedFiles: ["first.txt"], untrackedFiles: ["second.txt"] });

      const plan = planHook(input, state);

      assert.equal(plan.action, "commit-merge");
      assert.equal(plan.commit.subject, "auto(abcdef12): resolve merge conflict in first.txt (+1 more)");
    });

    it("uses resolved files when an already-staged merge has no detected path", () => {
      const input = makeInput({ tool_name: "apply_patch", tool_input: {} });
      const state = makeState({ inMerge: true, relPath: null, modifiedFiles: [], untrackedFiles: [], deletedFiles: [] });

      const plan = planHook(input, state);

      assert.equal(plan.action, "commit-merge");
      assert.equal(plan.commit.subject, "auto(abcdef12): resolve merge conflict in resolved files");
    });

    it("plans an already-staged merge before the ordinary skip", () => {
      const input = makeInput({ tool_name: "apply_patch", tool_input: {} });
      const state = makeState({
        inMerge: true,
        relPath: null,
        modifiedFiles: [],
        untrackedFiles: [],
        deletedFiles: [],
      });

      const plan = planHook(input, state);

      assert.equal(plan.action, "commit-merge");
      assert.deepEqual(plan.commit.changedPaths, []);
    });

    it("includes sync plan when remote exists", () => {
      const input = makeInput();
      const state = makeState({ inMerge: true, hasRemote: true });
      const plan = planHook(input, state);
      assert.equal(plan.action, "commit-merge");
      assert.deepEqual(plan.sync, { currentBranch: "main" });
    });

    it("sync is null when no remote", () => {
      const input = makeInput();
      const state = makeState({ inMerge: true, hasRemote: false });
      const plan = planHook(input, state);
      assert.equal(plan.action, "commit-merge");
      assert.equal(plan.sync, null);
    });
  });
});


describe("planHook normal commit", () => {
  it("produces commit-and-sync for a file edit", () => {
    const input = makeInput();
    const state = makeState();
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    assert.deepEqual(plan.commit.changedPaths, ["src/main.ts"]);
    assert.equal(plan.commit.subject, "auto(abcdef12): write src/main.ts");
    assert.equal(
      plan.commit.body,
      "Session: abcdef12-3456-7890-abcd-ef1234567890\nAgent: claude",
    );
  });

  it("uses tool_name in subject", () => {
    const input = makeInput({ tool_name: "Edit" });
    const state = makeState();
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    assert.match(plan.commit.subject, /^auto\(abcdef12\): edit src\/main\.ts$/);
  });

  it("defaults tool_name to 'update'", () => {
    const input = makeInput({ tool_name: null });
    const state = makeState();
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    assert.match(plan.commit.subject, /update src\/main\.ts/);
  });

  it("handles deletion path", () => {
    const input = makeInput({ tool_input: {} });
    const state = makeState({
      deletedFiles: ["old.ts", "stale.ts", "gone.ts"],
      relPath: null,
    });
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    assert.deepEqual(plan.commit.changedPaths, ["old.ts", "stale.ts", "gone.ts"]);
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
    assert.deepEqual(plan.commit.changedPaths, ["script.sh"]);
    assert.match(plan.commit.subject, /update script\.sh/);
  });

  it("stages an untracked new file when no file_path (e.g. Bash- or apply_patch-created)", () => {
    const input = makeInput({ tool_input: {} });
    const state = makeState({
      modifiedFiles: [],
      untrackedFiles: ["newfile.txt"],
      relPath: null,
    });
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    assert.deepEqual(plan.commit.changedPaths, ["newfile.txt"]);
    assert.match(plan.commit.subject, /update newfile\.txt/);
  });

  it("stages both an untracked new file and a modified tracked file together", () => {
    const input = makeInput({ tool_input: {} });
    const state = makeState({
      modifiedFiles: ["changed.sh"],
      untrackedFiles: ["brand-new.txt"],
      relPath: null,
    });
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    assert.deepEqual(plan.commit.changedPaths, ["changed.sh", "brand-new.txt"]);
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
    assert.deepEqual(plan.commit.changedPaths, ["changed.sh", "gone.ts"]);
  });

  it("sync is null when no remote", () => {
    const input = makeInput();
    const state = makeState({ hasRemote: false });
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    assert.equal(plan.sync, null);
  });

  it("includes sync plan on the current branch", () => {
    const input = makeInput();
    const state = makeState({ currentBranch: "trunk-sync-abc" });
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
    assert.deepEqual(plan.sync, { currentBranch: "trunk-sync-abc" });
  });

  it("body is null when no session or transcript", () => {
    const input = makeInput({ session_id: null, transcript_path: null });
    const state = makeState();
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-and-sync");
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
    assert.deepEqual(plan.commit.changedPaths, ["foo.ts"]);
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
    assert.deepEqual(plan.commit.changedPaths, ["foo.ts"]);
  });

});


describe("buildCommitPlanWithTask", () => {
  it("uses task as subject when provided", () => {
    const input = makeInput();
    const state = makeState();
    const commit = buildCommitPlanWithTask(input, state, "Fix the broken tests");
    assert.equal(commit.subject, "auto(abcdef12): Fix the broken tests");
  });

  it("the commit body retains its file, session, and agent provenance", () => {
    const input = makeInput();
    const state = makeState();

    const commit = buildCommitPlanWithTask(input, state, "Fix the broken tests");

    assert.equal(
      commit.body,
      "File: src/main.ts\nSession: abcdef12-3456-7890-abcd-ef1234567890\nAgent: claude",
    );
  });

  it("summarizes every detected path in an enriched commit without file_path or session provenance", () => {
    const input = makeInput({ session_id: null, transcript_path: null, tool_input: {} });
    const state = makeState({ relPath: null, modifiedFiles: ["first.txt"], deletedFiles: ["second.txt"] });

    const commit = buildCommitPlanWithTask(input, state, "Reconcile files");

    assert.equal(commit.subject, "auto: Reconcile files");
    assert.equal(commit.body, "File: first.txt (+1 more)");
    assert.deepEqual(commit.changedPaths, ["first.txt", "second.txt"]);
  });

  it("falls back to default plan when task is null", () => {
    const input = makeInput();
    const state = makeState();
    const commit = buildCommitPlanWithTask(input, state, null);
    assert.match(commit.subject, /write src\/main\.ts/);
  });
});


describe("buildSessionPrefix", () => {
  it("includes short session id", () => {
    assert.equal(buildSessionPrefix("abcdef1234567890"), "auto(abcdef12): ");
  });

  it("returns plain auto: when null", () => {
    assert.equal(buildSessionPrefix(null), "auto: ");
  });
});


describe("buildCommitBody", () => {
  it("includes session and agent", () => {
    const input = makeInput();
    const body = buildCommitBody(input, "src/main.ts");
    assert.equal(
      body,
      "Session: abcdef12-3456-7890-abcd-ef1234567890\nAgent: claude",
    );
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

  it("includes Agent: codex when Codex reports a compatibility tool name with a turn id", () => {
    const input = makeInput({ tool_name: "Bash", turn_id: "codex-turn" });

    const body = buildCommitBody(input, "src/main.ts");

    assert.match(body ?? "", /^Agent: codex$/m);
  });
});


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

  it("skips only a standalone XML tag line", () => {
    const content = jsonl({
      type: "user",
      message: { role: "user", content: "<context>\nActual task" },
    });
    assert.equal(extractTaskFromTranscript(content), "Actual task");

    const inline = jsonl({
      type: "user",
      message: { role: "user", content: "<Component> Fix the task" },
    });
    assert.equal(extractTaskFromTranscript(inline), "<Component> Fix the task");
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
    for (const messageContent of [
      ["First part", "Second part"],
      [{ type: "text", text: "First part" }, { type: "text", text: "Second part" }],
    ]) {
      const content = jsonl({
        type: "user",
        message: { role: "user", content: messageContent },
      });
      assert.equal(extractTaskFromTranscript(content), "First part");
    }
  });

  it("skips non-user messages", () => {
    const content = jsonl({ type: "assistant", message: { role: "assistant", content: "Sure" } });
    assert.equal(extractTaskFromTranscript(content), null);
  });

  it("returns null when the user message content is empty", () => {
    const content = jsonl({ type: "user", message: { role: "user", content: "" } });
    assert.equal(extractTaskFromTranscript(content), null);
  });

  it("returns null for an empty transcript", () => {
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


describe("classifyTimecards", () => {
  const now = new Date("2026-03-27T10:05:00.000Z");

  function makeTimecard(overrides: Partial<Timecard> = {}): Timecard {
    return {
      sessionId: "other-session-id",
      hostname: "my-macbook",
      clockedInAt: "2026-03-27T09:00:00.000Z",
      lastActiveAt: "2026-03-27T10:04:00.000Z",
      branch: "main",
      ...overrides,
    };
  }

  it("excludes the own session from every bucket", () => {
    const result = classifyTimecards("my-session", [makeTimecard({ sessionId: "my-session" })], now);
    assert.equal(result.active.length, 0);
    assert.equal(result.stale.length, 0);
    assert.equal(result.reapable.length, 0);
  });

  it("classifies a card whose heartbeat is within the display window as active", () => {
    const result = classifyTimecards(
      "my-session",
      [makeTimecard({ lastActiveAt: "2026-03-27T09:30:00.000Z" })],
      now,
    );
    assert.equal(result.active.length, 1);
    assert.equal(result.stale.length, 0);
    assert.equal(result.reapable.length, 0);
  });

  it("classifies a card past the display window but within the reap ttl as stale", () => {
    const result = classifyTimecards(
      "my-session",
      [makeTimecard({ lastActiveAt: "2026-03-27T08:00:00.000Z" })],
      now,
    );
    assert.equal(result.stale.length, 1);
    assert.equal(result.active.length, 0);
    assert.equal(result.reapable.length, 0);
  });

  it("classifies a card past the reap ttl as reapable", () => {
    const result = classifyTimecards(
      "my-session",
      [makeTimecard({ lastActiveAt: "2026-03-10T10:00:00.000Z" })],
      now,
    );
    assert.equal(result.reapable.length, 1);
    assert.equal(result.active.length, 0);
    assert.equal(result.stale.length, 0);
  });
});


describe("formatClockInMessage", () => {
  const now = new Date("2026-03-27T10:05:00.000Z");

  function card(overrides: Partial<Timecard> = {}): Timecard {
    return {
      sessionId: "abcdef12-3456-7890-abcd-ef1234567890",
      hostname: "my-macbook",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:04:30.000Z",
      branch: "main",
      ...overrides,
    };
  }

  it("returns null when no other agents are active", () => {
    assert.equal(formatClockInMessage([], now), null);
  });

  it("formats a single active agent", () => {
    const msg = formatClockInMessage([card()], now)!;
    assert.match(msg, /1 other agent active/);
    assert.match(msg, /abcdef12 on my-macbook/);
    assert.match(msg, /branch: main/);
    assert.match(msg, /30s ago/);
    assert.match(msg, /no action required/);
    assert.match(msg, /share resources/);
  });

  it("lists all active agents when multiple are present", () => {
    const msg = formatClockInMessage([
      card({ sessionId: "aaaa0000-0000-0000-0000-000000000000", hostname: "mac-1", lastActiveAt: "2026-03-27T10:04:00.000Z" }),
      card({ sessionId: "bbbb0000-0000-0000-0000-000000000000", hostname: "mac-2", branch: "feature", lastActiveAt: "2026-03-27T10:02:00.000Z" }),
    ], now)!;
    assert.match(msg, /2 other agents active/);
    assert.match(msg, /aaaa0000 on mac-1/);
    assert.match(msg, /bbbb0000 on mac-2/);
  });

  it("rounds the elapsed minutes to match wall time", () => {
    const msg = formatClockInMessage([card({ lastActiveAt: "2026-03-27T10:02:00.000Z" })], now)!;
    assert.match(msg, /3m ago/);
  });

  it("formats elapsed hours to match wall time", () => {
    const msg = formatClockInMessage([card({ lastActiveAt: "2026-03-27T08:05:00.000Z" })], now)!;
    assert.match(msg, /2h ago/);
  });
});

describe("formatSessionStartSummary", () => {
  const now = new Date("2026-03-27T10:05:00.000Z");

  function card(overrides: Partial<Timecard> = {}): Timecard {
    return {
      sessionId: "aaaa0000-0000-0000-0000-000000000000",
      hostname: "mac-1",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:04:00.000Z",
      branch: "main",
      ...overrides,
    };
  }

  it("returns null when no active card is present", () => {
    assert.equal(formatSessionStartSummary([], now), null);
  });

  it("lists an active card with branch, labelled to coordinate", () => {
    const msg = formatSessionStartSummary([card()], now)!;
    assert.match(msg, /aaaa0000 on mac-1/);
    assert.match(msg, /branch: main/);
    assert.match(msg, /active: coordinate/);
    assert.doesNotMatch(msg, /task:/);
  });
});


function jsonl(...objects: unknown[]): string {
  return objects.map((o) => JSON.stringify(o)).join("\n");
}
