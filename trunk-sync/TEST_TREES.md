## Domain: hook-plan

```
Domain: hook-plan (src: src/lib/hook-plan.ts; domain: src/lib/hook-plan.domain.test.ts; system: test/system/hook-sync.system.test.sh)

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

  buildCommitPlanWithTask
    when a task is provided
      then the task is used as the commit subject
      and the commit body retains its file, session, and agent provenance
    when the task is null
      then the default plan subject is used

  buildSessionPrefix
    when a session id is provided
      then the prefix includes the short session id
    when the session id is null
      then the prefix is plain `auto:`

  buildCommitBody
    when a session id is present
      then the body includes Session and Agent
    when no session id is present
      then the body is null
    when the input tool is Claude's Edit/Write/Bash
      then the body includes `Agent: claude`
    when the input tool is Codex's apply_patch/local_shell
      then the body includes `Agent: codex`
    when Codex reports a compatibility tool name with a turn id
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
    if the transcript contains no user message content
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

  classifyTimecards
    then the own session is excluded
    when a card's heartbeat is within the display window
      then it is classified active — recently alive; coordinate, do not duplicate
    when a card's heartbeat is older than the display window but within the reap ttl
      then it is classified stale — omitted from presence rosters, not reaped
    when a card's heartbeat is older than the reap ttl
      then it is classified reapable

  formatClockInMessage
    when no other agent is active
      then null is returned
    when one other agent is active
      then a single-agent message is returned
    when multiple agents are active
      then all are listed
    when an active agent's elapsed time is displayed
      then ages under a minute use seconds
      and ages under an hour use minutes
      and older ages use hours

  formatSessionStartSummary
    when no active card is present
      then null is returned
    when an active card is present
      then it is listed with branch, labelled active — another agent is recently alive on it; coordinate, do not duplicate
```

## Adapter: hook-execute

```
Adapter: hook-execute (src: src/lib/hook-execute.ts; adapter: src/lib/hook-execute.adapter.test.ts; system: test/system/hook-sync.system.test.sh)

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
      and the absence of a merge reports no merge in progress
      and the absence of a remote is reported
      and a configured remote uses "agents" as targetBranch
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
      and an enriched commit retains file, session, and agent provenance
      and the default subject is used if the transcript is unreadable
      and files are staged relative to the repository root when the hook runs from a subdirectory
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

  clockIn
    when timecard data is provided
      then the timeclock directory is created and a valid presence-only timecard is written
    when a timecard already exists for this session
      then clockedInAt is preserved across updates
      and lastActiveAt is bumped to now — the heartbeat that marks the agent recently alive

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

  executePlan with timecard touch
    when a commit fires and the session already has a timecard
      then lastActiveAt is updated and committed alongside the code change
    when a commit fires and the session has no timecard
      then no timecard is created
    when a trunk-sync conflict happens and other agents are active
      then exit 2 includes the conflict feedback and the active roster
    when another agent's card is older than the reap ttl
      then it is reaped as part of the same commit
    when another agent's card is within the reap ttl
      then it is preserved, not reaped

  runSessionStart
    when the session-start hook fires
      then the starting agent's timecard is created and synced
      and every other session's timecard is read and classified by heartbeat age, the starting session excluded
      when active cards are present
        then their labelled summary is appended to coordinate around automatic session presence
      when only stale cards are present
        then no session-start context is emitted because stale cards are not session summaries
      when only reapable cards (or none) remain
        then no session-start context is emitted
    if the timeclock directory does not exist
      then it is created for the starting session and the hook exits 0
    if no session id is provided
      then no timecard is created and nothing is printed

  runStop
    when the stop hook fires and the session has a timecard
      then its timecard is removed and the removal is synced, automatically clocking the session out
      and it always exits 0
    if the session has no timecard yet
      then it exits 0 without creating one — a session that never edited has no timecard to clock out
    if no session id is provided
      then it exits 0 without action
```

## Adapter: command-guard

```
Adapter: command-guard (src: src/lib/pre-tool-entry.ts; adapter: src/lib/pre-tool-entry.adapter.test.ts; system: test/system/hook-sync.system.test.sh; journey: test/journey/agent-hook-compatibility.journey.test.sh)

  when Claude Code sends a Bash command as a string
    then the command is classified and its decision is returned as the hook exit
  when Codex sends a local_shell command as an array
    then the command is classified and its decision is returned as the hook exit
  when the command is rejected
    then exit 2 and file-editing guidance are written to stderr
  when the command is allowed
    then exit 0 is returned without feedback
```

## Domain: command-guard

```
Domain: command-guard (src: src/lib/command-guard.ts; domain: src/lib/command-guard.domain.test.ts; adapter: src/lib/pre-tool-entry.adapter.test.ts; system: test/system/hook-sync.system.test.sh; journey: test/journey/agent-hook-compatibility.journey.test.sh)

  classifyCommand
    when a command does not start with git
      then it is allowed
    when a command is git clone, diff, log, or show with optional `-C <path>`
      then it is allowed
    when any other git command is received
      then it is rejected with file-editing guidance
```

## System: hook-sync

```
System: hook-sync (src: hooks/hooks.json, src/lib/hook-entry.ts, src/lib/session-start-entry.ts, src/lib/stop-entry.ts; system: test/system/hook-sync.system.test.sh; journey: test/journey/agent-hook-compatibility.journey.test.sh)

  every Edit/Write/Bash/apply_patch/local_shell tool use
    then the changed file is staged and committed
    and commits with a session record the session and originating agent provenance
    when a remote is configured
      then HEAD is pushed to the consumer repository's shared `agents` branch after the commit
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
    then the starting agent is clocked in without adding its own internal session id to agent context
    when other sessions have stale cards
      then they are omitted because timecards represent presence, not session summaries
    when other sessions have active cards
      then that recently-alive work is surfaced to coordinate around
    when only reapable cards remain
      then no session-start context is emitted
  every end of task
    then the agent's timecard is removed and synced, automatically clocking the session out for remote readers
    and the agent is never forced to act — the stop hook always exits 0
  when an agent is disrupted mid-task and a new session starts
    then the disrupted agent's stale card is omitted and failing tests remain the authoritative signal of unfinished work
  when a merge conflict arises during sync
    then exit 2 surfaces self-contained conflict-resolution instructions
    and active timecards are surfaced again to coordinate around ongoing sessions
    when the agent edits the conflicted file and the hook fires again
      then the merge is completed
  when a push is rejected
    then a single pull-and-push retry is attempted
```

## Journey: agent-hook-compatibility

```
Journey: agent-hook-compatibility (journey: test/journey/agent-hook-compatibility.journey.test.sh)

  when Claude Code uses the published plugin in a consumer repository
    if it attempts a write-side git command
      then the command is rejected with instructions to edit file content instead
    when it edits a file after the rejection
      then the edit is committed and pushed to the consumer repository's shared `agents` branch
      and the commit records the Claude session and agent provenance
    when the session ends
      then its presence is removed from the shared branch

  when Codex uses the published plugin in a consumer repository
    if it attempts a write-side git command
      then the command is rejected with instructions to edit file content instead
    when it edits a file after the rejection
      then the edit is committed and pushed to the consumer repository's shared `agents` branch
      and the commit records the Codex session and agent provenance
    when the session ends
      then its presence is removed from the shared branch
```
