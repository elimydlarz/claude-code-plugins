## hook-plan

```
Domain: hook-plan (src: src/lib/hook-plan.ts; domain: src/lib/hook-plan.test.ts; system: test/trunk-sync.test.sh)

  parseHookInput
    when called with complete input
      then every field is populated
    when called with input missing optional fields
      then those fields default to null
    if the input is not valid JSON
      then it throws

  planHook skip conditions
    when there is no file_path and no deleted, modified, or untracked files
      then the plan is skip
    when the file is outside the repo
      then the plan is skip
    when the file is gitignored
      then the plan is skip

  planHook merge state
    while a merge is in progress
      when the session is known
        then the plan is commit-merge with a session prefix
      when the session is unknown
        then the plan is commit-merge without a session prefix
      when a remote is configured
        then a sync plan is included
      when no remote is configured
        then sync is null

  planHook normal commit
    when a file edit is processed
      then the plan is commit-and-sync
      and the tool name appears in the subject
      and a missing tool name defaults to "update"
    when a deletion is processed
      then the deleted path is staged
    when a modified tracked file is processed without a file_path
      then the modification is staged (covers chmod and other Bash-caused changes)
    when an untracked new file is present without a file_path
      then the new file is staged (covers files created by Bash and Codex apply_patch — build output, generators, scaffolding)
    when both deletions and modifications are present
      then both are staged in the same commit
    when both an untracked new file and a modified tracked file are present
      then both are staged in the same commit
    when no remote is configured
      then sync is null
    when the current branch is a worktree branch (not the target)
      then a sync plan is still included
    when no session id and no transcript_path are present
      then the commit body is null
    when the tool is Codex's apply_patch and no file_path is given
      then dirty tracked files are staged
    when the tool is Codex's local_shell and no file_path is given
      then dirty tracked files are staged
    when transcript_path is in the payload
      then the body includes `TranscriptPath: <path>`
    when transcript_path is absent
      then the body omits TranscriptPath

  buildCommitPlanWithTask
    when a task is provided
      then the task is used as the commit subject
    when the task is null
      then the default plan subject is used

  buildSessionPrefix
    when a session id is provided
      then the prefix includes the short session id
    when the session id is null
      then the prefix is plain `auto:`

  buildCommitBody
    when both session id and transcript path are present
      then the body includes Session and TranscriptPath
    when only the session id is present
      then the body includes Session only
    when no session id is present
      then the body is null
    when the input tool is Claude's Edit/Write/Bash
      then the body includes `Agent: claude`
    when the input tool is Codex's apply_patch/local_shell
      then the body includes `Agent: codex`

  extractTaskFromTranscript
    when the transcript starts with a user message
      then the first user message is returned as the task
    if a user message is hook feedback
      then it is skipped
    if a user message starts with `Implement the following plan:`
      then the header is skipped
    if a user message contains XML tags
      then the tags are stripped
    if a user message starts with markdown headers
      then the headers are stripped
    when the extracted task exceeds 72 chars
      then it is truncated at 72 chars
    when the user message content is an array
      then array content is handled
    if a transcript entry is not a user message
      then it is skipped
    if the user message content is empty
      then null is returned
    if a transcript line is not valid JSON
      then it is skipped without throwing

  summarizeDeletions
    when called with no files
      then an empty summary is returned
    when called with one file
      then the filename is returned
    when called with multiple files
      then the count and a representative filename are returned

  buildClockInPlan
    when the runtime context provides a session id and branch
      then a clock-in plan with the timecard path is returned
      and the timecard initializes lastStep and remainingSteps to null
    if the session id is null
      then null is returned
    if the current branch is empty
      then `detached` is recorded as the branch

  planHook clock-in plan
    when runtime context is provided
      then a clock-in plan is included alongside the commit plan
    if no runtime context is provided
      then clockIn is null
    while a merge is in progress
      then a clock-in plan is included on commit-merge

  classifyTimecards
    then the own session is excluded
    when a card's heartbeat is within the display window
      then it is classified active — recently alive; coordinate, do not duplicate
    when a card's heartbeat is older than the display window but within the reap ttl
      then it is classified stale — possibly disrupted; surfaced for resume, not reaped
    when a card's heartbeat is older than the reap ttl
      then it is classified reapable even with unfinished remaining steps — abandoned

  formatClockInMessage
    when no other agent is active and this is not the first clock-in
      then null is returned
    when one other agent is active without a task
      then a single-agent message is returned
    when an active agent has a task
      then the task description is included
    when an active agent has recorded progress
      then its last completed step and remaining steps are included on that agent's line
    when multiple agents are active
      then all are listed
    when the elapsed minutes value is rounded
      then the formatting matches the elapsed wall time
    when this is the first clock-in
      then the message tells the agent to run the test suite before starting
      and it explains failing tests are the authoritative signal of unfinished WIP to resume, with active cards as advisory context for who already holds work
      and it scopes resumable WIP to work not held by an active agent
    when this is the first clock-in and other agents are active
      then both the active roster and the run-tests nudge are included

  formatSessionStartSummary
    when neither an active nor a stale card is present
      then null is returned
    when an active card is present
      then it is listed with branch, task, last completed step, and remaining steps, labelled active — another agent is recently alive on it; coordinate, do not duplicate
    when a stale card is present
      then it is listed labelled stale — possibly disrupted; verify against the test suite before resuming, since it may already be done
    when a card has no recorded remaining steps
      then it is still listed, pointing at its committed timecard context rather than omitted
    when a card's heartbeat age is an hour or more
      then its age is rendered in hours
```

## git

```
Domain: git (src: src/lib/git.ts; domain: src/lib/git.test.ts; system: none)

  getGitRoot
    when inside a git repository
      then the repository root path is returned
    if not inside a git repository
      then null is returned

  parseFileRef
    when called with `path:line`
      then file and line are returned
    if no colon is present
      then it throws
    if the line is non-numeric
      then it throws
    if the line is negative
      then it throws
    if the line is zero
      then it throws
    if the file does not exist
      then it throws

  extractSessionId
    when the body contains `Session: <uuid>`
      then the uuid is returned
    when there is no Session line
      then null is returned
    when the body is empty
      then null is returned

  extractTranscriptPath
    when the body contains `TranscriptPath: <path>`
      then the path is returned
    when there is no TranscriptPath line
      then null is returned

  extractAgent
    when the body contains `Agent: <name>`
      then `<name>` is returned
    if there is no Agent line and TranscriptPath is under `~/.codex/`
      then "codex" is returned
    if there is no Agent line and TranscriptPath is absent or under `~/.claude/`
      then "claude" is returned

  blame and getCommitBody
    when called on a committed line
      then the commit SHA is returned
    when called on an uncommitted line
      then the SHA is all zeros
    when lines have been added above the blamed line
      then the original line number from the blamed commit is returned
    when called on a newly added line
      then the original line number matches the line in the blamed commit
    when a later commit inserts a line above
      then the original line number reflects the older commit's numbering

  getCommitSubject
    when called with a commit sha
      then the commit's subject line is returned

  getCommitDate
    when called with a commit sha
      then the commit's human-readable date is returned

  getCommitTimestamp
    when called on a commit
      then the commit's ISO timestamp is returned

  commandExists
    when called for a binary on PATH
      then true is returned
    when called for a non-existent command
      then false is returned

  shortSha
    when called with a full SHA
      then the first 8 characters are returned

  findSnapshotInCommit
    when the commit contains a `.transcripts/` file
      then the filename is returned
    when the commit contains no `.transcripts/` file
      then null is returned
```

## hook-execute

```
Use-case: hook-execute (src: src/lib/hook-execute.ts; use-case: src/lib/hook-execute.test.ts; system: test/trunk-sync.test.sh)

  gatherRepoState
    when called outside a git repo
      then null is returned
    when called inside a repo
      then the repo root and git dir are reported
      and a file outside the repo is detected as outside
      and a gitignored file is detected as gitignored
      and the current branch name is reported
      and a detached HEAD reports an empty currentBranch
      and a merge in progress is reported when MERGE_HEAD is present
      and the presence of staged changes is reported
      and the absence of a remote is reported
      and a configured remote with no `target-branch` override defaults targetBranch to "agents"
    while `target-branch` is set in `.trunk-sync/config`
      then targetBranch reads the configured value instead of the "agents" default
    when no file_path is provided
      then deleted tracked files are detected
      and modified tracked files are detected
      and permission-only changes are detected
      and untracked new files are detected (files created by Bash/apply_patch)
      and gitignored untracked files are excluded
    when a file_path is provided
      then working-tree detection (modified and untracked) is skipped (file_path mode is exclusive)

  getRuntimeContext
    then the host machine's hostname is reported

  findWorktreeForBranch
    when the branch has an active worktree
      then its path is returned
    when the branch has no worktree
      then null is returned

  executePlan
    when action is skip
      then nothing is committed
    when action is commit-and-sync
      then the file is staged and committed
      and the body with session is included in the commit
      and exit 0 results when nothing is staged
      and a deletion is staged
      and modified files (e.g. permission changes) are staged and committed
      and the commit subject is enriched from the transcript when available
      and the default subject is used if the transcript is unreadable
    when action is commit-merge
      then the merge is completed
    if the merge is unresolved
      then the git exit code is returned

  executeSync
    when called with a remote configured
      then HEAD is pulled and pushed
    when push is rejected
      then a single pull-and-push retry is attempted
    if the retried push also fails
      then exit 2 is returned with push-failure feedback
    if pull produces a merge conflict
      then exit 2 is returned with conflict feedback
    if the target branch does not exist on the remote yet
      then the pull is skipped and the push creates it — no conflict is reported
    when on a non-target worktree branch
      then the target branch is merged in
    if merging the target branch into the worktree branch conflicts
      then exit 2 is returned with conflict feedback
    when push succeeds
      then the local target branch is updated to match origin
    when the local target branch is checked out in another worktree
      then it is fast-forwarded in that worktree instead of by fetch

  amendWithTranscriptSnapshot
    while `commit-transcripts=true` — the explicit opt-in
      when the hook fires with a transcript path
        then the transcript is snapshotted into `.transcripts/` and the code commit is amended to include it
      if the snapshot operation fails
        then the hook continues without aborting
    while `commit-transcripts` is unset or any value other than `true` — the default-off behaviour
      then no snapshot is created
    if no transcript_path is provided
      then no snapshot is created
    if no session id is provided
      then no snapshot is created

  clockIn
    when a session id and runtime context are present
      then the timeclock directory is created and a valid timecard is written
    when a timecard already exists for this session
      then clockedInAt is preserved across updates
      and lastActiveAt is bumped to now — the heartbeat that marks the agent recently alive
      and task is re-derived from the current transcript on each update
      and lastStep and remainingSteps are preserved across updates, since only the progress recorder sets them

  readTimecards
    when the timeclock directory does not exist
      then an empty list is returned
    when the directory contains multiple timecards
      then all are read
    if a timecard file is malformed
      then it is skipped without aborting

  reapCards
    when given the session ids classified reapable
      then each card file is removed and its path is returned
    when a timecard file is already gone
      then it is handled gracefully

  executePlan with clock-in
    when a commit fires with runtime context
      then a timecard is committed alongside the code change
    when the agent clocks in for the first time in a session
      then exit 2 is returned with a message telling the agent to run the tests and resume any unfinished WIP
    when other agents are active
      then exit 2 is returned with a throttled roster of who is active
    when the throttle file is fresh
      then the roster message is suppressed
    when another agent's card is older than the reap ttl
      then it is reaped as part of the same commit, regardless of remaining steps
    when another agent's card is within the reap ttl
      then it is preserved, not reaped — active or stale, the handover survives for someone to resume
    if `.trunk-sync` is unwritable
      then the hook still exits 0 (clock-in is best-effort)

  runSessionStart
    when the session-start hook fires
      then the starting agent's own session id and the instruction to record progress with the plugin-bundled progress recorder are printed to stdout for injection into context
      and every other session's timecard is read and classified by heartbeat age, the starting session excluded
      when active or stale cards are present
        then their labelled summary is appended — active to coordinate around, stale to verify against the tests and resume
      when only reapable cards (or none) remain
        then only the own-id and record-progress instruction are printed
    if the timeclock directory does not exist
      then the own-id and record-progress instruction are still printed and the hook exits 0
    if no session id is provided
      then nothing is printed

  runStop
    when the stop hook fires and the session has a timecard
      then its heartbeat (lastActiveAt) is bumped and the update is synced, so remote readers see it fresh through a long no-edit turn
      and it always exits 0 — progress is never forced
    when the heartbeat was already refreshed by a recent tool-use sync
      then no commit is made — a fresh heartbeat is not duplicated
    if the session has no timecard yet
      then it exits 0 without creating one — a session that never edited has no handover to keep alive
    if no session id is provided
      then it exits 0 without action
```

## seance

```
Use-case: seance (src: src/commands/seance.ts; use-case: src/commands/seance.test.ts; system: none)

  seance usage
    when `--help` or `-h` is passed
      then usage is printed without launching a CLI
    when no file:line argument is given
      then usage is printed

  seance --inspect
    when the blamed commit is a trunk-sync commit
      then the SHA, subject, session id, and queried line are printed without launching a CLI
    when the blamed line has shifted from its original position
      then the reported line also includes the blamed commit's original line number

  seance preconditions
    if the blamed line has uncommitted changes
      then it exits 1 with a message naming the line
    if the blamed commit was not made by trunk-sync
      then it exits 1 with a message identifying the commit

  seance launch failures
    if the resolved agent's CLI is not on PATH
      then it exits 1 naming the missing CLI
    if creating the worktree at the blamed commit fails
      then it exits 1
    if the transcript cannot be rewound to the commit timestamp
      then it exits 1

  seance --list
    when the repository contains trunk-sync commits
      then deduplicated sessions are printed in a table
    when the repository contains no trunk-sync commits
      then nothing is listed

  seance default mode
    if the blamed commit has no transcript snapshot and no derivable transcript
      then it exits 1 with an error
    when a stale worktree exists from a previous seance
      then it is removed and recreated cleanly
    when a `.transcripts/` snapshot is committed in the code commit
      then the snapshot is preferred over the derived transcript path
    when there is no snapshot but the commit body records a TranscriptPath
      then the transcript at that path is used
    when the blamed line has shifted in the current file
      then the prompt uses the original line number from the blamed commit
      and the prompt includes the blamed line's code content

  seance default mode (Claude commit)
    when the blamed commit's `Agent:` is `claude` (or absent)
      then the transcript is rewound by RFC3339 timestamp into a new sessionId
      and the rewound transcript is written under `~/.claude/projects/<worktree-slug>/`
      and `claude --resume <newId> --allowedTools <readonly> --permission-mode plan --append-system-prompt <seance>` is spawned in the worktree
      when claude exits
        then the rewound transcript file is deleted
        and the worktree is removed

  seance default mode (Codex commit)
    when the blamed commit's `Agent:` is `codex`
      then the rollout is rewound by RFC3339 timestamp into a new conversation UUID
      and the rewound rollout's `SessionMeta.payload.id` and `payload.cwd` are rewritten
      and the rollout is written to `~/.codex/sessions/<Y>/<M>/<D>/rollout-<ts>-<newuuid>.jsonl`
      and `codex exec --sandbox read-only --ask-for-approval never --skip-git-repo-check -C <worktree> resume <newuuid> <seance-prompt>` is spawned
      when codex exits
        then the rewound rollout file is deleted
        and the worktree is removed
```

## rewind-codex-rollout

```
Domain: rewindCodexRollout (src: src/commands/seance-codex.ts; domain: src/commands/seance-codex.test.ts; system: none)

  rewindCodexRollout
    when called with rollout lines, a commit timestamp, and a worktree path
      then lines whose RFC3339 timestamp is later than the commit timestamp are dropped
      and the SessionMeta line's `payload.id` is replaced with a new UUID
      and the SessionMeta line's `payload.cwd` is replaced with the worktree path
      and a target rollout path under `~/.codex/sessions/<Y>/<M>/<D>/rollout-<ts>-<newuuid>.jsonl` is returned
    if no line's timestamp is at or before the commit timestamp
      then null is returned
    if a rollout line is not valid JSON
      then it is skipped
    if a rollout line has no timestamp
      then it is skipped
    if a `session_meta` line has no payload
      then it is passed through with id and cwd unchanged
```

## config

```
Use-case: config (src: src/commands/config.ts; use-case: src/commands/config.test.ts; system: none)

  config command
    then `--help` or `-h` prints usage
    if run outside a git repo
      then `git init` is run first, establishing a repo to store config in
    when `config` is called with no key
      then every key is printed
        when a key is set in `.trunk-sync/config`
          then its explicit value is shown
        when a key is not set in `.trunk-sync/config`
          then its built-in default value is shown
    when a key is set
      then it is persisted to `.trunk-sync/config` in the repo
      and the change is staged and committed
      while a remote is configured
        then the commit is pushed
      if the push fails
        then the command still succeeds — the commit stands locally for the next sync to pick up
      and a subsequent `config` call shows the value
      if the key already holds that value
        then no new commit is created and the command still reports success
      if the value contains shell metacharacters (`$()`, backticks, quotes, spaces)
        then it is persisted and committed verbatim, never interpreted by a shell (no injected command runs, the commit message is intact)
    when `config <key>` is called
      then the single value is printed
    when `config <key>` is called for a key that has a built-in default and is unset
      then the default is printed (e.g. `commit-transcripts` defaults to `false`, so session records are not committed by default; `target-branch` defaults to `agents`)
    if `config <key>` is called for an unknown key
      then it exits 1 with `Unknown key`
    when `config unset <key>` is called
      then the key is removed from `.trunk-sync/config`
      and the change is staged and committed
      while a remote is configured
        then the commit is pushed
      if the push fails
        then the command still succeeds — the commit stands locally for the next sync to pick up
    if `config unset <key>` is called for a key that does not exist
      then it exits 1
    if `config --unset` is called with no key
      then it exits 1 with a usage message
    when the config file contains comments and blank lines
      then they are preserved on read
```

## progress

```
Use-case: progress (src: src/lib/progress.ts; use-case: src/commands/progress.test.ts; system: test/trunk-sync.test.sh)

  progress recorder
    then `--help` prints usage
    when called with a session id, a last step, and remaining steps
      then the matching timecard's lastStep and remainingSteps are both set
      and its heartbeat (lastActiveAt) is refreshed
      and clockedInAt, task, and branch are preserved
    when called with `--last` only
      then lastStep is set and remainingSteps is left untouched — a partial update never destroys the handover
    when called with `--next` only
      then remainingSteps is set and lastStep is left untouched
    when called with `--next ""`
      then remainingSteps is cleared, marking the work done
    when no timecard yet exists for the session id
      then a timecard is created carrying the recorded progress
    if the session id is missing
      then it exits 1 with a usage message
```

## hook-sync

```
System: hook-sync (system: test/trunk-sync.test.sh; journey: test/functional/docker-entrypoint.sh)

  functional handover harness
    when the handover case is run with the Claude harness
      then the shared fixture and verifier are used
      and the real Claude CLI edits, records progress, and receives the handover
    when the handover case is run with the Codex harness
      then the shared fixture and verifier are used
      and the real Codex CLI edits, records progress, and receives the handover
      and Codex session and hook logs are appended to the transcript for hook evidence
    then hook runner failures are rejected without matching ordinary command stderr

  every Edit/Write/Bash/apply_patch/local_shell tool use
    then the changed file is staged and committed
    when a remote is configured
      then HEAD is pushed to the remote's default branch after the commit
    when no remote is configured
      then push is silently skipped
  every Bash tool use whose command starts with `git`
    then the command is rejected with feedback directing the agent to use Edit
    when the git command is `clone`, `diff`, `log`, or `show` (or their `-C <path>` variants)
      then it is allowed through
  every local_shell tool use whose command starts with `git`
    then the command is rejected with the same feedback as Bash
    when the git command is in the read-only allowlist
      then it is allowed through
  every session start
    then the starting agent is handed its own session id and the command to record progress
    when other sessions have stale cards
      then that possibly-disrupted work is surfaced to verify against the tests and resume
    when other sessions have active cards
      then that recently-alive work is surfaced to coordinate around
    when only reapable cards remain
      then nothing is surfaced beyond the agent's own record-progress instruction
  every end of task
    then the agent's timecard heartbeat is bumped and synced, marking it recently alive for remote readers
    and the agent is never forced to act — the stop hook always exits 0
  when an agent is disrupted mid-task and a new session starts
    then the disrupted agent's stale card is surfaced as a handover, corroborated against the failing tests before resuming
    when the resumer finishes and the original card ages past the reap ttl
      then it is swept on the next agent's commit
  when an agent records progress and the hook later fires
    then the progress-bearing timecard is committed and pushed, propagating the handover to other machines
  when a merge conflict arises during sync
    then exit 2 surfaces self-contained conflict-resolution instructions
    when the agent edits the conflicted file and the hook fires again
      then the merge is completed
  when a push is rejected
    then a single pull-and-push retry is attempted
  while `commit-transcripts=true`
    when the hook commits a code change with a transcript path
      then the transcript is snapshotted into `.transcripts/` and the commit is amended to include it
```
