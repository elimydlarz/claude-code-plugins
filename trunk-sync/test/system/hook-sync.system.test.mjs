import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { before, describe, it } from "node:test"
import { fileURLToPath } from "node:url"

const scenarios = fileURLToPath(new URL("./hook-sync.scenarios.sh", import.meta.url))
let result

before(() => {
  result = spawnSync("bash", [scenarios], {
    encoding: "utf-8",
    env: { ...process.env, NODE_TEST_CONTEXT: undefined },
  })
  assert.equal(result.status, 0, result.stdout + result.stderr)
})

function verifies(...labels) {
  return () => {
    for (const label of labels) {
      assert.match(result.stdout, new RegExp(`ok \\d+ - ${escapePattern(label)}(?:\\n|$)`), result.stdout)
    }
  }
}

function escapePattern(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

describe("System: hook-sync", () => {
  describe("every Edit/Write/Bash/apply_patch/local_shell tool use", () => {
    it("then the changed file is staged and committed", verifies(
      "no remote still commits locally",
      "tool name lowercased in subject",
      "new untracked file via Bash creates a commit",
      "codex apply_patch: one new commit",
      "codex local_shell: one new commit",
    ))
    it("and commits with a session record the session and originating agent provenance", verifies(
      "body contains Session line",
      "body contains originating Agent line",
      "codex local_shell: Session: trailer in body",
      "codex local_shell: Agent provenance in body",
    ))
    describe("when a remote is configured", () => {
      it("then HEAD is pushed to the consumer repository's shared `agents` branch after the commit", verifies(
        "commit reached remote",
        "codex apply_patch add: new file reached the remote",
      ))
    })
    describe("when no remote is configured", () => {
      it("then push is silently skipped", verifies("no remote exits 0", "no remote still commits locally"))
    })
  })

  describe("every Bash tool use whose command starts with `git`", () => {
    describe("when the command is git clone or only inspects repository, worktree, or history state", () => {
      it("then it is allowed through", verifies(
        "git-block: git clone is allowed",
        "git-block: git diff is allowed",
        "git-block: git log is allowed",
        "git-block: git show is allowed",
        "git-block: git status is allowed",
        "git-block: git branch inspection is allowed",
        "git-block: git reflog inspection is allowed",
        "git-block: git blame is allowed",
        "git-block: git ls-files is allowed",
        "git-block: git remote inspection is allowed",
        "git-block: git config reads are allowed",
        "git-block: git tag inspection is allowed",
        "git-block: git worktree inspection is allowed",
        "git-block: git stash inspection is allowed",
        "git-block: git -C <path> diff is allowed",
        "git-block: git -C <path> log is allowed",
        "git-block: git -C <path> show is allowed",
        "git-block: git -C <path> clone is allowed",
      ))
    })
    describe("if the git command can change repository, worktree, configuration, or remote state", () => {
      it("then it is rejected with feedback directing the agent to edit files and leave git writes to trunk-sync", verifies(
        "git-block: git push is blocked",
        "git-block: push gets TRUNK-SYNC feedback",
        "git-block: git commit is blocked",
        "git-block: git add is blocked",
        "git-block: git checkout is blocked",
        "git-block: git stash is blocked",
        "git-block: git stash pop is blocked",
      ))
    })
  })

  describe("every local_shell tool use whose command starts with `git`", () => {
    describe("when the command is git clone or only inspects repository, worktree, or history state", () => {
      it("then it is allowed through", verifies(
        "local_shell git-block: array git diff allowed",
        "local_shell git-block: array git log allowed",
        "local_shell git-block: array git -C <path> diff allowed",
        "local_shell git-block: array git status allowed",
        "local_shell git-block: array git branch inspection allowed",
      ))
    })
    describe("if the git command can change repository, worktree, configuration, or remote state", () => {
      it("then it is rejected with the same feedback as Bash", verifies(
        "local_shell git-block: array git push blocked",
        "local_shell git-block: array git push gets feedback",
        "local_shell git-block: string git commit blocked",
      ))
    })
  })

  describe("every session start", () => {
    it("then the starting agent is clocked in without adding its own internal session id to agent context", verifies(
      "session-start: A is clocked in without own session context",
      "timecard: sessionId written",
    ))
    describe("when other sessions have stale cards", () => {
      it("then they are omitted because timecards represent presence, not session summaries", verifies(
        "session-start: stale cards are not surfaced as active presence",
        "session-start: stale cards do not surface disruption language",
      ))
    })
    describe("when other sessions have active cards", () => {
      it("then that recently-alive work is surfaced to coordinate around", verifies(
        "session-start: active roster shown",
        "session-start: A's timecard is surfaced",
      ))
    })
    describe("when only reapable cards remain", () => {
      it("then no session-start context is emitted", verifies(
        "session-start reapable-only: no context is surfaced",
        "session-start reapable-only: no active roster is surfaced",
      ))
    })
  })

  describe("every end of task", () => {
    it("then the agent's timecard is removed and synced, automatically clocking the session out for remote readers", verifies(
      "stop: clock-out is committed",
      "stop: local timecard is removed",
      "stop: timecard removal is synced to the remote",
    ))
    it("and the agent is never forced to act — the stop hook always exits 0", verifies(
      "stop: the stop hook always exits 0 — the agent is never forced to act",
    ))
  })

  describe("when an agent is disrupted mid-task and a new session starts", () => {
    it("then the disrupted agent's stale card is omitted", verifies("session-start: stale cards are not surfaced as active presence"))
  })

  describe("when a merge conflict arises during sync", () => {
    it("then exit 2 surfaces self-contained conflict-resolution instructions", verifies(
      "pull conflict exits 2",
      "stderr contains TRUNK-SYNC CONFLICT",
    ))
    it("and active timecards are surfaced again to coordinate around ongoing sessions", verifies(
      "concurrent conflict: loser sees active timecards again",
    ))
    describe("when the agent edits the conflicted file and the hook fires again", () => {
      it("then the merge is completed", verifies(
        "merge conflict resolved exits 0",
        "merge commit subject contains resolve merge conflict",
      ))
    })
  })

  describe("when a push is rejected", () => {
    it("then a single pull-and-push retry is attempted", verifies("push retry succeeds after non-conflicting pull"))
  })
})
