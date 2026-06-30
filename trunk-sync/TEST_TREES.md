# Test Trees

These trees are the behaviour contract for trunk-sync. Each tree reifies one test file; each path corresponds to one `describe`/`it` in that file.

Migration note: trunk-sync was previously specified as a flat `## Requirements` list in `CLAUDE.md`. That section has been retired in favour of these trees. Build and dev invariants that aren't behavioural (`dist-tracked`, `version-sync`, `doc-alignment`) still live in `CLAUDE.md` as conventions.

## Test Trees

### Domain: hook-plan (src: src/lib/hook-plan.ts; unit: src/lib/hook-plan.test.ts; integration: none; functional: test/trunk-sync.test.sh)

  parseHookInput
    when called with complete input
      then every field is populated
    when called with input missing optional fields
      then those fields default to null
    if the input is not valid JSON
      then it throws

  planHook skip conditions
    when there is no file_path, no deletions, and no modifications
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
    when both deletions and modifications are present
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
    when a card is local with a live PID
      then it is live, with certainty — the process is running
    when a card is local with a dead PID
      then it is ended, with certainty — the process is gone
    when a card is remote with a heartbeat within the staleness window
      then it is live, presumed — a remote PID cannot be checked
    when a card is remote with a heartbeat older than the staleness window
      then it is ended, presumed
    where a card is live and has unfinished remaining steps
      then it is classified active
    where a card is ended and has unfinished remaining steps
      then it is classified disrupted
    where a card is live and has no remaining steps
      then it is classified done and kept — the agent may take another task
    where a card is ended and has no remaining steps
      then it is classified done and reapable

  formatClockInMessage
    when no other agents are clocked in and this is not the first clock-in
      then null is returned
    when one other agent is clocked in without a task
      then a single-agent message is returned
    when an agent has a task
      then the task description is included
    when an agent has recorded progress
      then its last completed step and remaining steps are included on that agent's line
    when multiple agents are clocked in
      then all are listed
    when the elapsed minutes value is rounded
      then the formatting matches the elapsed wall time
    when this is the first clock-in
      then the message tells the agent to run the test suite before starting
      and it explains failing tests are checkpoints of unfinished WIP to resume
      and it scopes resumable WIP to work not part of a still-clocked-in agent's
    when this is the first clock-in and other agents are clocked in
      then both the clocked-in roster and the run-tests nudge are included

  formatSessionStartSummary
    when no card is active or disrupted
      then null is returned
    when a disrupted card is present
      then it is listed with branch, task, last completed step, and remaining steps, labelled disrupted — the handover to resume
    when an active card was determined live with certainty (local, live PID)
      then it is listed labelled active — another agent's running process holds it; coordinate, do not duplicate
    when an active card's liveness is only presumed (remote, fresh heartbeat)
      then it is listed labelled active but flagged possibly-disrupted — liveness is inferred from a heartbeat, not a checked PID
    when a card is done
      then it is not listed — finished work is not a handover

### Domain: git (src: src/lib/git.ts; unit: src/lib/git.test.ts; integration: none; functional: none)

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

### Use-case: hook-execute (src: src/lib/hook-execute.ts; unit: none; integration: src/lib/hook-execute.test.ts; functional: test/trunk-sync.test.sh)

  gatherRepoState
    when called outside a git repo
      then null is returned
    when called inside a repo
      then the repo root and git dir are reported
      and a file outside the repo is detected as outside
      and a gitignored file is detected as gitignored
      and the current branch name is reported
      and a detached HEAD reports an empty currentBranch
      and the absence of a remote is reported
      and a configured remote reads targetBranch from origin/HEAD
    if origin/HEAD is not a symbolic ref
      then targetBranch falls back to "main"
      and no git error is written to stderr
    when no file_path is provided
      then deleted tracked files are detected
      and modified tracked files are detected
      and permission-only changes are detected
    when a file_path is provided
      then modified-files detection is skipped (file_path mode is exclusive)

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
    if pull produces a merge conflict
      then exit 2 is returned with conflict feedback
    when on a non-target worktree branch
      then the target branch is merged in
    when push succeeds
      then the local target branch is updated to match origin

  amendWithTranscriptSnapshot
    while `commit-transcripts` is unset or any value other than `false` — the default-on behaviour
      when the hook fires with a transcript path
        then the transcript is snapshotted into `.transcripts/` and the code commit is amended to include it
      if the snapshot operation fails
        then the hook continues without aborting
    while `commit-transcripts=false` — the explicit opt-out
      then no snapshot is created
    if no transcript_path is provided
      then no snapshot is created

  clockIn
    when a session id and runtime context are present
      then the timeclock directory is created and a valid timecard is written
    when a timecard already exists for this session
      then clockedInAt is preserved across updates
      and lastActiveAt is bumped to now — the heartbeat that marks the agent live
      and task is re-derived from the current transcript on each update
      and lastStep and remainingSteps are preserved across updates, since only `trunk-sync progress`/`clockout` set them

  readTimecards
    when the timeclock directory does not exist
      then an empty list is returned
    when the directory contains multiple timecards
      then all are read
    if a timecard file is malformed
      then it is skipped without aborting

  isProcessAlive
    when called with the current process pid
      then true is returned
    when called with a non-existent pid
      then false is returned

  clockOutStale
    when a card is classified done and reapable
      then it is removed and its path returned
    when a card has unfinished remaining steps
      then it is never removed — a handover (active or disrupted) is preserved for resumption
    when a card is classified done and kept
      then it is left in place — the agent is still live and may take another task
    when a timecard file is already gone
      then it is handled gracefully

  executePlan with clock-in
    when a commit fires with runtime context
      then a timecard is committed alongside the code change
    when the agent clocks in for the first time in a session
      then exit 2 is returned with a message telling the agent to run the tests and resume any unfinished WIP
    when other agents are clocked in
      then exit 2 is returned with a throttled clock-in message
    when the throttle file is fresh
      then the clock-in message is suppressed
    when a clocked-in agent has a dead PID
      then it is clocked out as part of the same commit
    if `.trunk-sync` is unwritable
      then the hook still exits 0 (clock-in is best-effort)

  runSessionStart
    when the session-start hook fires
      then the starting agent's own session id and the instruction to clock in with `trunk-sync clockin <id>` are printed to stdout for injection into context
      and every other session's timecard is read and classified, the starting session excluded
      when disrupted or active cards are present
        then their state-labelled summary is appended — disrupted to resume, active to coordinate around
      when only done cards (or none) remain
        then only the own-id and clock-in instruction are printed
    if the timeclock directory does not exist
      then the own-id and clock-in instruction are still printed and the hook exits 0
    if no session id is provided
      then nothing is printed

  runStop
    when the stop hook fires and stop_hook_active is set
      then it exits 0 without forcing, preventing the force → record → stop loop
    when the stop hook fires at the end of a task
      then the session's timecard heartbeat (lastActiveAt) is bumped, marking the agent live
      and the agent is prompted via exit 2 to record progress — `trunk-sync progress <id> --last … --next …` — or to clock out with `trunk-sync clockout <id>` if the task is complete
    if the session has no timecard yet
      then one is created first (passive clock-in fallback), then its heartbeat is bumped
    if no session id is provided
      then it exits 0 without action

### Use-case: install (src: src/commands/install.ts; unit: src/commands/install.test.ts; integration: none; functional: none)

  install command
    then `--help` prints usage
    if jq is not on PATH
      then it fails with an install hint
    if the claude CLI is not on PATH
      then it fails with an install hint
    when run outside a git repo with project scope
      then a warning is emitted
    when run outside a git repo with user scope
      then the warning is suppressed (cwd is irrelevant for user scope)
    if the scope is neither `project` nor `user`
      then it is rejected
    when run with a valid scope
      then the scope is passed to `claude plugin marketplace add` and `claude plugin install`
    when run with `--client codex`
      then an `elimydlarz` entry is upserted into `$HOME/.agents/plugins/marketplace.json`
      and the operation is idempotent across repeated runs
      and unrelated existing plugins in the marketplace are preserved
    if `--client` is neither `claude` nor `codex`
      then it is rejected

### Use-case: seance (src: src/commands/seance.ts; unit: none; integration: src/commands/seance.test.ts; functional: none)

  seance --inspect
    when the blamed commit is a trunk-sync commit
      then the SHA, subject, and session id are printed without launching a CLI
    when the blamed line has shifted from its original position
      then the original line number from the blamed commit is reported

  seance preconditions
    if the blamed line has uncommitted changes
      then it exits 1 with a message naming the line
    if the blamed commit was not made by trunk-sync
      then it exits 1 with a message identifying the commit

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
    when the blamed line has shifted in the current file
      then the prompt uses the original line number from the blamed commit
      and the actual line content is read from the current file

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

### Domain: rewindCodexRollout (src: src/commands/seance-codex.ts; unit: src/commands/seance-codex.test.ts; integration: none; functional: none)

  rewindCodexRollout
    when called with rollout lines, a commit timestamp, and a worktree path
      then lines whose RFC3339 timestamp is later than the commit timestamp are dropped
      and the SessionMeta line's `payload.id` is replaced with a new UUID
      and the SessionMeta line's `payload.cwd` is replaced with the worktree path
      and a target rollout path under `~/.codex/sessions/<Y>/<M>/<D>/rollout-<ts>-<newuuid>.jsonl` is returned
    if no line's timestamp is at or before the commit timestamp
      then null is returned

### Use-case: config (src: src/commands/config.ts; unit: src/commands/config.test.ts; integration: none; functional: none)

  config command
    when no config file exists
      then `config` prints empty
    when a key is set
      then it is persisted to `~/.trunk-sync`
      and a subsequent `config` call shows the value
    when `config <key>` is called
      then the single value is printed
    when `config <key>` is called for a key that has a built-in default and is unset
      then the default is printed (e.g. `commit-transcripts` defaults to `true`, so session records are committed and pushed unless opted out)
    if `config <key>` is called for an unknown key
      then it exits 1 with `Unknown key`
    when `config unset <key>` is called
      then the key is removed
    if `config unset <key>` is called for a key that does not exist
      then it exits 1
    when the config file contains comments and blank lines
      then they are preserved on read

### Use-case: progress (src: src/commands/progress.ts; unit: src/commands/progress.test.ts; integration: none; functional: test/trunk-sync.test.sh)

  progress command
    then `--help` prints usage
    when called with a session id, a last step, and remaining steps
      then the matching timecard's lastStep and remainingSteps are set
      and its heartbeat (lastActiveAt) is refreshed
      and clockedInAt, task, pid, and branch are preserved
    when no timecard yet exists for the session id
      then a timecard is created carrying the recorded progress
    if the session id is missing
      then it exits 1 with a usage message

### Use-case: clockin (src: src/commands/clockin.ts; unit: src/commands/clockin.test.ts; integration: none; functional: test/trunk-sync.test.sh)

  clockin command
    then `--help` prints usage
    when called with a session id
      then a timecard for that session is created, or its heartbeat refreshed if it already exists
      and the session id is echoed back as confirmation for use in later updates
    when called with `--task <text>`
      then the task description is recorded on the card
    if the session id is missing
      then it exits 1 with a usage message

### Use-case: clockout (src: src/commands/clockout.ts; unit: src/commands/clockout.test.ts; integration: none; functional: test/trunk-sync.test.sh)

  clockout command
    then `--help` prints usage
    when called with a session id
      then the card's remaining steps are cleared, marking the work done
      and the card becomes reapable once it is no longer live
    when called with `--last <text>`
      then the final completed step is recorded before the remaining steps are cleared
    if the session id is missing
      then it exits 1 with a usage message

### System: hook-sync (functional: test/trunk-sync.test.sh; journey: test/functional/docker-entrypoint.sh)

  every Edit/Write/Bash tool use
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
    then the starting agent is handed its own session id and the command to clock in
    when other sessions have disrupted cards
      then that disrupted work is surfaced as the handover to resume
    when other sessions have active cards
      then that active work is surfaced to coordinate around — labelled certain for a local live PID, possibly-disrupted for a remote heartbeat
    when only done cards remain
      then nothing is surfaced beyond the agent's own clock-in instruction
  every end of task
    then the agent's timecard heartbeat is bumped, marking it live
    and the agent is forced to record its progress, or clock out if the task is complete
    when stop_hook_active is set
      then the force is skipped to prevent loops
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
