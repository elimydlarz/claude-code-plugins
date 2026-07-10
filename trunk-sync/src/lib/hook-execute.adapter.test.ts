import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { describe, it } from "node:test";

const scenarios = fileURLToPath(new URL("./hook-execute.scenarios.js", import.meta.url));

function verifies(pattern: string): () => void {
  return () => {
    const result = spawnSync(process.execPath, ["--test", "--test-reporter=tap", `--test-name-pattern=${pattern}`, scenarios], {
      encoding: "utf-8",
      env: { ...process.env, NODE_TEST_CONTEXT: undefined },
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /# pass [1-9]/, result.stdout);
  };
}

describe("Adapter: hook-execute", () => {
  describe("gatherRepoState", () => {
    describe("when called outside a git repo", () => {
      it("then null is returned", verifies("returns null outside a git repo"));
    });
    describe("when called inside a repo", () => {
      it("then the repo root and git dir are reported", verifies("detects repo root and git dir"));
      it("and a file outside the repo is detected as outside", verifies("detects file outside repo"));
      it("and a gitignored file is detected as gitignored", verifies("detects gitignored files"));
      it("and the current branch name is reported", verifies("reports current branch name"));
      it("and a detached HEAD reports an empty currentBranch", verifies("reports empty currentBranch in detached HEAD"));
      it("and a merge in progress is reported when MERGE_HEAD is present", verifies("reports a merge in progress via MERGE_HEAD"));
      it("and the absence of a merge reports no merge in progress", verifies("reports no merge in progress when MERGE_HEAD is absent"));
      it("and the absence of a remote is reported", verifies("detects no remote"));
      it("and a configured remote uses \"agents\" as targetBranch", verifies("uses agents as targetBranch when a remote is configured"));
    });
    describe("when no file_path is provided", () => {
      it("then deleted tracked files are detected", verifies("detects deleted files"));
      it("and modified tracked files are detected", verifies("detects modified files when no file_path"));
      it("and permission-only changes are detected", verifies("detects permission changes when no file_path"));
      it("and untracked new files are detected (files created by Bash/apply_patch)", verifies("detects untracked new files when no file_path"));
      it("and gitignored untracked files are excluded", verifies("excludes gitignored untracked files"));
    });
    describe("when a file_path is provided", () => {
      it("then working-tree detection (modified and untracked) is skipped (file_path mode is exclusive)", verifies("does not detect modified or untracked files when file_path is provided"));
    });
  });

  describe("getRuntimeContext", () => {
    it("then the host machine's hostname is reported", verifies("reports the host machine's hostname"));
  });

  describe("findWorktreeForBranch", () => {
    describe("when the branch has an active worktree", () => {
      it("then its path is returned", verifies("finds worktree for a branch"));
    });
    describe("when the branch has no worktree", () => {
      it("then null is returned", verifies("returns null for missing branch"));
    });
  });

  describe("executePlan", () => {
    describe("when action is skip", () => {
      it("then nothing is committed", verifies("skips on action=skip"));
    });
    describe("when action is commit-and-sync", () => {
      it("then the file is staged and committed", verifies("stages and commits a file"));
      it("and the body with session is included in the commit", verifies("includes body with session in commit"));
      it("and exit 0 results when nothing is staged", verifies("exits 0 when nothing staged"));
      it("and a deletion is staged", verifies("stages file deletions"));
      it("and modified files (e.g. permission changes) are staged and committed", verifies("stages and commits modified files"));
      it("and the commit subject is enriched from the transcript when available", verifies("enriches commit subject from transcript"));
      it("and an enriched commit retains file, session, and agent provenance", verifies("an enriched commit retains file, session, and agent provenance"));
      it("and the default subject is used if the transcript is unreadable", verifies("uses default subject when transcript unreadable"));
      it("and files are staged relative to the repository root when the hook runs from a subdirectory", verifies("stages repo-root-relative files when the hook runs from a subdirectory"));
    });
    describe("when action is commit-merge", () => {
      it("then the merge is completed", verifies("completes a merge"));
    });
    describe("if the merge is unresolved", () => {
      it("then the git exit code is returned", verifies("returns git exit code on unresolved merge"));
    });
  });

  describe("executeSync", () => {
    describe("when called with a remote configured", () => {
      it("then HEAD is pulled and pushed", verifies("pulls and pushes to remote"));
    });
    describe("when push is rejected", () => {
      it("then a single pull-and-push retry is attempted", verifies("retries push after rejection"));
    });
    describe("if the retried push also fails", () => {
      it("then exit 2 is returned with push-failure feedback", verifies("returns exit 2 with push-failure feedback when the retried push also fails"));
    });
    describe("if pull produces a merge conflict", () => {
      it("then exit 2 is returned with conflict feedback", verifies("returns exit 2 on merge conflict during pull"));
    });
    describe("if the target branch does not exist on the remote yet", () => {
      it("then the pull is skipped and the push creates it — no conflict is reported", verifies("creates the target branch on first sync when it doesn't exist on the remote yet"));
    });
    describe("when on a non-target worktree branch", () => {
      it("then the target branch is merged in", verifies("merges target branch on non-target worktree branch"));
    });
    describe("if merging the target branch into the worktree branch conflicts", () => {
      it("then exit 2 is returned with conflict feedback", verifies("returns exit 2 with conflict feedback when merging the local target branch into the worktree branch conflicts"));
    });
    describe("when push succeeds", () => {
      it("then the local target branch is updated to match origin", verifies("updates local target branch after push"));
    });
    describe("when the local target branch is checked out in another worktree", () => {
      it("then it is fast-forwarded in that worktree instead of by fetch", verifies("fast-forwards the local target branch in its own worktree when fetch cannot update it directly"));
    });
  });

  describe("clockIn", () => {
    describe("when timecard data is provided", () => {
      it("then the timeclock directory is created and a valid presence-only timecard is written", verifies("creates timeclock directory and writes valid timecard"));
    });
    describe("when a timecard already exists for this session", () => {
      it("then clockedInAt is preserved across updates", verifies("preserves clockedInAt from existing timecard"));
      it("and lastActiveAt is bumped to now — the heartbeat that marks the agent recently alive", verifies("preserves clockedInAt from existing timecard"));
    });
  });

  describe("readTimecards", () => {
    describe("when the timeclock directory does not exist", () => {
      it("then an empty list is returned", verifies("returns empty when no timeclock directory"));
    });
    describe("when the directory contains multiple timecards", () => {
      it("then all are read", verifies("reads multiple timecards"));
    });
    describe("if a timecard file is malformed", () => {
      it("then it is skipped without aborting", verifies("skips malformed files"));
    });
  });

  describe("reapCards", () => {
    describe("when given the session ids classified reapable", () => {
      it("then each card file is removed and its path is returned", verifies("removes each given card file and returns its path"));
    });
    describe("when a timecard file is already gone", () => {
      it("then it is handled gracefully", verifies("handles already-removed files gracefully"));
    });
  });

  describe("executePlan with timecard touch", () => {
    describe("when a commit fires and the session already has a timecard", () => {
      it("then lastActiveAt is updated and committed alongside the code change", verifies("updates and commits an existing timecard alongside the code change"));
    });
    describe("when a commit fires and the session has no timecard", () => {
      it("then no timecard is created", verifies("creates no timecard when the session has no timecard"));
    });
    describe("when a trunk-sync conflict happens and other agents are active", () => {
      it("then exit 2 includes the conflict feedback and the active roster", verifies("returns exit 2 with conflict feedback and active roster when sync conflicts"));
    });
    describe("when another agent's card is older than the reap ttl", () => {
      it("then it is reaped as part of the same commit", verifies("reaps another agent's card once its heartbeat is past the reap ttl"));
    });
    describe("when another agent's card is within the reap ttl", () => {
      it("then it is preserved, not reaped", verifies("preserves another agent's card whose heartbeat is within the reap ttl"));
    });
  });

  describe("runSessionStart", () => {
    describe("when the session-start hook fires", () => {
      it("then the starting agent's timecard is created and synced", verifies("pushes the starting agent's timecard when a remote is configured"));
      it("and every other session's timecard is read and classified by heartbeat age, the starting session excluded", verifies("excludes the starting session's own timecard from the roster"));
      describe("when active cards are present", () => {
        it("then their labelled summary is appended to coordinate around automatic session presence", verifies("appends the active roster when another agent is clocked in"));
      });
      describe("when only stale cards are present", () => {
        it("then no session-start context is emitted because stale cards are not session summaries", verifies("omits stale cards because timecards are presence only"));
      });
      describe("when only reapable cards (or none) remain", () => {
        it("then no session-start context is emitted", verifies("omits the roster when the only other card is past the reap ttl"));
      });
    });
    describe("if the timeclock directory does not exist", () => {
      it("then it is created for the starting session and the hook exits 0", verifies("creates the timeclock directory when it does not exist"));
    });
    describe("if no session id is provided", () => {
      it("then no timecard is created and nothing is printed", verifies("returns null when there is no session id"));
    });
  });

  describe("runStop", () => {
    describe("when the stop hook fires and the session has a timecard", () => {
      it("then its timecard is removed and the removal is synced, automatically clocking the session out", verifies("pushes the removed timecard to the remote when a remote is configured"));
      it("and it always exits 0", verifies("never throws even when the post-clock-out sync fails"));
    });
    describe("if the session has no timecard yet", () => {
      it("then it exits 0 without creating one — a session that never edited has no timecard to clock out", verifies("creates no card and exits cleanly when the session has no timecard"));
    });
    describe("if no session id is provided", () => {
      it("then it exits 0 without action", verifies("does nothing when no session id is provided"));
    });
  });
});
