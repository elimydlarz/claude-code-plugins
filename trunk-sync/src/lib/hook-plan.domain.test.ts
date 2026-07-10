import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { describe, it } from "node:test";

const scenarios = fileURLToPath(new URL("./hook-plan.scenarios.js", import.meta.url));

function verifies(pattern: string): () => void {
  return () => {
    const result = spawnSync(process.execPath, ["--test", "--test-reporter=tap", `--test-name-pattern=${pattern}`, scenarios], { encoding: "utf-8" });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /# pass [1-9]/, result.stdout);
  };
}

describe("Domain: hook-plan", () => {
  describe("parseHookInput", () => {
    describe("when called with complete input", () => {
      it("then every field is populated", verifies("parses complete input"));
    });
    describe("when called with input missing optional fields", () => {
      it("then those fields default to null", verifies("defaults missing fields to null"));
    });
    describe("if the input is not valid JSON", () => {
      it("then it throws", verifies("throws on invalid JSON"));
    });
  });

  describe("planHook skip conditions", () => {
    describe("when there is no file_path and no deleted, modified, or untracked files", () => {
      it("then the plan is skip", verifies("skips when no file_path and no deleted, modified, or untracked files"));
    });
    describe("when the file is outside the repo", () => {
      it("then the plan is skip", verifies("skips when file is outside the repo"));
    });
    describe("when the file is gitignored", () => {
      it("then the plan is skip", verifies("skips when file is gitignored"));
    });
  });

  describe("planHook merge state", () => {
    describe("while a merge is in progress", () => {
      describe("when the session is known", () => {
        it("then the plan is commit-merge with a session prefix", verifies("produces commit-merge with session prefix"));
      });
      describe("when the session is unknown", () => {
        it("then the plan is commit-merge without a session prefix", verifies("produces commit-merge without session prefix"));
      });
      describe("when a remote is configured", () => {
        it("then a sync plan is included", verifies("includes sync plan when remote exists"));
      });
      describe("when no remote is configured", () => {
        it("then sync is null", verifies("planHook merge state.*sync is null when no remote"));
      });
    });
  });

  describe("planHook normal commit", () => {
    describe("when a file edit is processed", () => {
      it("then the plan is commit-and-sync", verifies("produces commit-and-sync for a file edit"));
      it("and the tool name appears in the subject", verifies("uses tool_name in subject"));
      it("and a missing tool name defaults to \"update\"", verifies("defaults tool_name to 'update'"));
    });
    describe("when a deletion is processed", () => {
      it("then the deleted path is staged", verifies("handles deletion path"));
    });
    describe("when a modified tracked file is processed without a file_path", () => {
      it("then the modification is staged (covers chmod and other Bash-caused changes)", verifies("handles modified files .* when no file_path"));
    });
    describe("when an untracked new file is present without a file_path", () => {
      it("then the new file is staged (covers files created by Bash and Codex apply_patch — build output, generators, scaffolding)", verifies("stages an untracked new file when no file_path"));
    });
    describe("when both deletions and modifications are present", () => {
      it("then both are staged in the same commit", verifies("handles both deletions and modifications together"));
    });
    describe("when both an untracked new file and a modified tracked file are present", () => {
      it("then both are staged in the same commit", verifies("stages both an untracked new file and a modified tracked file together"));
    });
    describe("when no remote is configured", () => {
      it("then sync is null", verifies("planHook normal commit.*sync is null when no remote"));
    });
    describe("when the current branch is a worktree branch (not the target)", () => {
      it("then a sync plan is still included", verifies("includes sync plan on worktree branch"));
    });
    describe("when no session id and no transcript_path are present", () => {
      it("then the commit body is null", verifies("body is null when no session or transcript"));
    });
    describe("when the tool is Codex's apply_patch and no file_path is given", () => {
      it("then dirty tracked files are staged", verifies("Codex apply_patch with no file_path stages dirty tracked files"));
    });
    describe("when the tool is Codex's local_shell and no file_path is given", () => {
      it("then dirty tracked files are staged", verifies("Codex local_shell with no file_path stages dirty tracked files"));
    });
  });

  describe("buildCommitPlanWithTask", () => {
    describe("when a task is provided", () => {
      it("then the task is used as the commit subject", verifies("uses task as subject when provided"));
      it("and the commit body retains its file, session, and agent provenance", verifies("the commit body retains its file, session, and agent provenance"));
    });
    describe("when the task is null", () => {
      it("then the default plan subject is used", verifies("falls back to default plan when task is null"));
    });
  });

  describe("buildSessionPrefix", () => {
    describe("when a session id is provided", () => {
      it("then the prefix includes the short session id", verifies("includes short session id"));
    });
    describe("when the session id is null", () => {
      it("then the prefix is plain `auto:`", verifies("returns plain auto: when null"));
    });
  });

  describe("buildCommitBody", () => {
    describe("when a session id is present", () => {
      it("then the body includes Session and Agent", verifies("includes session and agent"));
    });
    describe("when no session id is present", () => {
      it("then the body is null", verifies("returns null when no session"));
    });
    describe("when the input tool is Claude's Edit/Write/Bash", () => {
      it("then the body includes `Agent: claude`", verifies("includes Agent: claude when tool is Claude's Edit/Write/Bash"));
    });
    describe("when the input tool is Codex's apply_patch/local_shell", () => {
      it("then the body includes `Agent: codex`", verifies("includes Agent: codex when tool is Codex's apply_patch/local_shell"));
    });
    describe("when Codex reports a compatibility tool name with a turn id", () => {
      it("then the body includes `Agent: codex`", verifies("includes Agent: codex when Codex reports a compatibility tool name with a turn id"));
    });
  });

  describe("extractTaskFromTranscript", () => {
    describe("when the transcript starts with a user message", () => {
      it("then the first user message is returned as the task", verifies("extracts first user message"));
    });
    describe("if a user message is hook feedback", () => {
      it("then it is skipped", verifies("skips hook feedback lines"));
    });
    describe("if a user message starts with `Implement the following plan:`", () => {
      it("then the header is skipped", verifies("skips 'Implement the following plan:' header"));
    });
    describe("if a user message contains XML tags", () => {
      it("then the tags are stripped", verifies("skips XML tags"));
    });
    describe("if a user message starts with markdown headers", () => {
      it("then the headers are stripped", verifies("strips markdown headers"));
    });
    describe("when the extracted task exceeds 72 chars", () => {
      it("then it is truncated at 72 chars", verifies("truncates at 72 chars"));
    });
    describe("when the user message content is an array", () => {
      it("then array content is handled", verifies("handles array content"));
    });
    describe("if a transcript entry is not a user message", () => {
      it("then it is skipped", verifies("skips non-user messages"));
    });
    describe("if the user message content is empty", () => {
      it("then null is returned", verifies("returns null when the user message content is empty"));
    });
    describe("if the transcript contains no user message content", () => {
      it("then null is returned", verifies("returns null for an empty transcript"));
    });
    describe("if a transcript line is not valid JSON", () => {
      it("then it is skipped without throwing", verifies("handles invalid JSON lines gracefully"));
    });
  });

  describe("summarizeDeletions", () => {
    describe("when called with no files", () => {
      it("then an empty summary is returned", verifies("returns empty for no files"));
    });
    describe("when called with one file", () => {
      it("then the filename is returned", verifies("returns filename for single file"));
    });
    describe("when called with multiple files", () => {
      it("then the count and a representative filename are returned", verifies("summarizes multiple files"));
    });
  });

  describe("classifyTimecards", () => {
    it("then the own session is excluded", verifies("excludes the own session from every bucket"));
    describe("when a card's heartbeat is within the display window", () => {
      it("then it is classified active — recently alive; coordinate, do not duplicate", verifies("classifies a card whose heartbeat is within the display window as active"));
    });
    describe("when a card's heartbeat is older than the display window but within the reap ttl", () => {
      it("then it is classified stale — omitted from presence rosters, not reaped", verifies("classifies a card past the display window but within the reap ttl as stale"));
    });
    describe("when a card's heartbeat is older than the reap ttl", () => {
      it("then it is classified reapable", verifies("classifies a card past the reap ttl as reapable"));
    });
  });

  describe("formatClockInMessage", () => {
    describe("when no other agent is active", () => {
      it("then null is returned", verifies("returns null when no other agents are active"));
    });
    describe("when one other agent is active", () => {
      it("then a single-agent message is returned", verifies("formats a single active agent"));
    });
    describe("when multiple agents are active", () => {
      it("then all are listed", verifies("lists all active agents when multiple are present"));
    });
    describe("when an active agent's elapsed time is displayed", () => {
      it("then ages under a minute use seconds", verifies("formats a single active agent"));
      it("and ages under an hour use minutes", verifies("rounds the elapsed minutes to match wall time"));
      it("and older ages use hours", verifies("formats elapsed hours to match wall time"));
    });
  });

  describe("formatSessionStartSummary", () => {
    describe("when no active card is present", () => {
      it("then null is returned", verifies("returns null when no active card is present"));
    });
    describe("when an active card is present", () => {
      it("then it is listed with branch, labelled active — another agent is recently alive on it; coordinate, do not duplicate", verifies("lists an active card with branch, labelled to coordinate"));
    });
  });
});
