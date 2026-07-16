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
    assert.doesNotMatch(result.stdout, /^1\.\.0$/m, `No scenario matched ${pattern}`);
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
    });
    describe("when no file_path is provided", () => {
      it("then deleted tracked files are detected", verifies("detects deleted files"));
      it("and modified tracked files are detected", verifies("detects modified files when no file_path"));
      it("and unresolved paths retaining conflict markers or matching a conflict side are excluded from detected resolved paths", verifies("excludes unresolved paths retaining conflict markers or matching a conflict side until resolved"));
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
      describe("when commit metadata and changed paths contain shell syntax or Git pathspec magic", () => {
        it("then they are passed literally to Git", verifies("passes commit metadata and changed paths containing shell syntax or Git pathspec magic literally to Git"));
        it("and no shell expression is evaluated", verifies("does not evaluate shell expressions from commit metadata"));
      });
    });
    describe("when action is commit-merge", () => {
      it("then the merge is completed", verifies("completes a merge"));
      it("and the commit records session and agent provenance", verifies("records session and agent provenance on the merge commit"));
      describe("when Codex resolves conflicts without a file_path", () => {
        it("then every detected resolved path is staged and the merge is completed", verifies("completes a Codex merge without file_path"));
        describe("if only some of multiple conflicted files are resolved", () => {
          it("then only the resolved paths are staged", verifies("keeps unresolved Codex merge paths open when only some conflicts are resolved"));
          it("and the merge remains open with the other paths unmerged", verifies("keeps unresolved Codex merge paths open when only some conflicts are resolved"));
        });
        describe("if a markerless modify/delete conflict has not been edited", () => {
          it("then the path remains unmerged and no merge commit is created", verifies("keeps an untouched markerless Codex conflict unmerged"));
        });
      });
      describe("when Claude sends a file_path that retains conflict markers or is otherwise unconfirmed", () => {
        it("then the path remains unmerged and marker-neutral guidance is returned", verifies("keeps a Claude merge open when its file_path retains conflict markers or matches a conflict side"));
      });
      describe("when the resolution is already staged", () => {
        it("then the merge is completed without requiring a file_path", verifies("completes an already-staged merge without file_path"));
      });
    });
    describe("if the merge is unresolved", () => {
      it("then the git exit code is returned", verifies("returns git exit code on unresolved merge"));
    });
  });

  describe("executeSync", () => {
    describe("when called from a checked-out branch with a remote configured", () => {
      it("then the remote is checked for that branch", verifies("creates the current branch on first sync when it doesn't exist on the remote yet"));
      it("and an existing branch is pulled before the current branch is pushed to its remote counterpart", verifies("pulls and pushes the current branch to its remote counterpart"));
    });
    describe("when the checked-out branch differs from another local branch", () => {
      it("then sync does not merge that other branch into the checked-out branch", verifies("does not merge another local branch"));
    });
    describe("when push is rejected", () => {
      it("then exactly one pull-and-push retry is attempted", verifies("retries push exactly once after rejection"));
      describe("when the current branch was created remotely after the initial pull", () => {
        it("then that branch is pulled before the retry push", verifies("retries after the branch is created remotely"));
      });
    });
    describe("if the retried push also fails", () => {
      it("then exit 2 is returned with safe push-failure feedback", verifies("returns exit 2 with push-failure feedback when the retried push also fails"));
      it("and the feedback asks the agent to retry after the underlying condition is corrected without prescribing Git writes", verifies("returns safe retry guidance without prescribing Git writes"));
    });
    describe("if pull produces a merge conflict", () => {
      describe("when Git reports unmerged paths", () => {
        it("then exit 2 is returned with conflict feedback", verifies("returns exit 2 on merge conflict during pull"));
        it("and the feedback uses tool-neutral file-edit guidance", verifies("returns exit 2 on merge conflict during pull"));
      });
    });
    describe("if pull fails without unmerged paths", () => {
      it("then exit 2 is returned with generic remote-failure feedback", verifies("returns generic remote failure when pull fails without unmerged paths"));
      it("and no conflict markers are claimed", verifies("does not claim conflict markers for a generic pull failure"));
    });
    describe("if Git cannot inspect unmerged paths after a pull failure", () => {
      it("then the inspection failure is propagated", verifies("propagates an unmerged-path inspection failure"));
    });
    describe("if the checked-out branch does not exist on the remote yet", () => {
      it("then the pull is skipped and the push creates it — no conflict is reported", verifies("creates the current branch on first sync when it doesn't exist on the remote yet"));
    });
    describe("if no branch is checked out", () => {
      it("then sync fails before pulling or pushing and identifies that a branch must be checked out", verifies("fails before sync when no branch is checked out"));
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
    describe("if the session id is not a safe filename component", () => {
      it("then clock-in fails without writing outside the timeclock directory", verifies("rejects unsafe session ids without writing outside the timeclock directory"));
    });
  });

  describe("readTimecards", () => {
    describe("when the timeclock directory does not exist", () => {
      it("then an empty list is returned", verifies("returns empty when no timeclock directory"));
    });
    describe("when the directory contains multiple timecards", () => {
      it("then all are read", verifies("reads multiple timecards"));
    });
    describe("if a timecard file has invalid JSON, missing, empty, or wrongly typed identity fields, an invalid timestamp, an unsafe session id, or an id that differs from its filename", () => {
      it("then reading fails and identifies the malformed file", verifies("fails on malformed files"));
    });
  });

  describe("reapCards", () => {
    describe("when given the session ids classified reapable", () => {
      it("then each card file is removed and its path is returned", verifies("removes each given card file and returns its path"));
    });
    describe("when a timecard file is already gone", () => {
      it("then it is handled gracefully", verifies("handles already-removed files gracefully"));
    });
    describe("if a session id is not a safe filename component", () => {
      it("then reaping fails without removing anything outside the timeclock directory", verifies("rejects unsafe session ids without removing anything outside the timeclock directory"));
    });
  });

  describe("executePlan with timecard touch", () => {
    describe("when a commit fires and the session already has a timecard", () => {
      it("then lastActiveAt is updated and committed alongside the code change", verifies("updates and commits an existing timecard alongside the code change"));
    });
    describe("when a commit fires and the session has no timecard", () => {
      it("then no timecard is created", verifies("creates no timecard when the session has no timecard"));
    });
    describe("if the existing session timecard is malformed", () => {
      it("then the commit fails and identifies the malformed timecard", verifies("fails a commit that touches a malformed existing session timecard"));
    });
    describe("when a trunk-sync conflict happens and other agents are active", () => {
      it("then exit 2 includes the conflict feedback and the active roster", verifies("returns exit 2 with conflict feedback and active roster when sync conflicts"));
    });
    describe("when another agent's card is older than the reap ttl", () => {
      it("then it is reaped as part of the same commit", verifies("reaps another agent's card once its heartbeat is past the reap ttl"));
      describe("if the classified card disappears before its path can be staged", () => {
        it("then no unrelated repository path is staged", verifies("stages no unrelated repository path when a classified card disappears before staging"));
      });
    });
    describe("when another agent's card is within the reap ttl", () => {
      it("then it is preserved, not reaped", verifies("preserves another agent's card whose heartbeat is within the reap ttl"));
    });
  });

  describe("runSessionStart", () => {
    describe("when the session-start hook fires", () => {
      it("then the starting agent's timecard is created and synced", verifies("pushes the starting agent's timecard when a remote is configured"));
      it("and every other session's timecard is read and classified by heartbeat age, the starting session excluded", verifies("excludes the starting session's own timecard from the roster"));
      it("and unrelated staged or unstaged source and timecard changes remain uncommitted", verifies("preserves unrelated staged or unstaged source and timecard changes during clock-in"));
      describe("when active cards are present", () => {
        it("then active cards are appended to coordinate around automatic session presence", verifies("appends the active roster when another agent is clocked in"));
      });
      describe("when only stale cards are present", () => {
        it("then no session-start context is emitted because stale cards are not session summaries", verifies("omits stale cards because timecards are presence only"));
      });
      describe("when only reapable cards (or none) remain", () => {
        it("then no session-start context is emitted", verifies("omits the roster when the only other card is past the reap ttl"));
      });
    });
    describe("if the clock-in commit fails", () => {
      it("then the hook reports that presence is local-only with the commit failure", verifies("reports local-only presence when clock-in commit fails"));
    });
    describe("if clock-in sync fails", () => {
      it("then the hook reports that presence is local-only with the sync failure", verifies("reports local-only presence when clock-in sync fails"));
    });
    describe("if the timeclock directory does not exist", () => {
      it("then it is created for the starting session and the hook exits 0", verifies("creates the timeclock directory when it does not exist"));
    });
    describe("if no session id is provided", () => {
      it("then no timecard is created and nothing is printed", verifies("returns null when there is no session id"));
    });
    describe("if no branch is checked out", () => {
      it("then no timecard is created and branch guidance is returned", verifies("does not clock in from detached HEAD"));
    });
  });

  describe("runStop", () => {
    describe("when the stop hook fires and the session has a timecard", () => {
      it("then its timecard is removed and the removal is synced, automatically clocking the session out", verifies("pushes the removed timecard to the remote when a remote is configured"));
      it("and it always exits 0", verifies("never throws even when the post-clock-out sync fails"));
    });
    describe("if the clock-out commit fails", () => {
      it("then the hook still exits 0", verifies("never throws when the clock-out commit fails"));
      it("and warns that the remote may still show the session as active with the commit failure", verifies("warns that remote presence may be stale when clock-out commit fails"));
    });
    describe("if clock-out sync fails", () => {
      it("then the hook still exits 0", verifies("never throws even when the post-clock-out sync fails"));
      it("and warns that the remote may still show the session as active with the sync failure", verifies("warns that remote presence may be stale when clock-out sync fails"));
    });
    describe("if the session has no timecard yet", () => {
      it("then it exits 0 without creating one — a session that never edited has no timecard to clock out", verifies("creates no card and exits cleanly when the session has no timecard"));
    });
    describe("if no session id is provided", () => {
      it("then it exits 0 without action", verifies("does nothing when no session id is provided"));
    });
    describe("if clock-out cannot read or remove the timecard", () => {
      it("then it still exits 0 with a stale-remote warning", verifies("returns a stale-remote warning when clock-out cannot read or remove the timecard"));
    });
  });
});
