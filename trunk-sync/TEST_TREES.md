## Domain: hook-plan

```
Domain: hook-plan (src: src/lib/hook-plan.ts, src/lib/entry-input.ts; domain: src/lib/hook-plan.domain.test.ts; system: test/system/hook-sync.system.test.mjs)

  parseHookInput
    when called with complete input
      then every field is populated
    when called with input missing optional fields
      then those fields default to null
    if the input is syntactically invalid or its object fields have invalid types
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
        then the plan is commit-merge with a session prefix and session and agent provenance
      when the session is unknown
        then the plan is commit-merge without a session prefix
      when Codex provides no file_path
        then the plan includes every detected resolved path
        and the subject summarizes the detected resolved paths
      when the resolution is already staged and no working-tree changes remain
        then the plan is still commit-merge
        and the subject identifies resolved files
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
    when a remote is configured
      then the sync plan identifies the current branch
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
      and detected paths are summarized when file and session metadata are absent
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
    if a user message starts with a standalone XML tag line
      then that tag line is skipped
    if a user message starts with markdown headers
      then the headers are stripped
    when the extracted task exceeds 72 chars
      then it is truncated at 72 chars
    when the user message content is an array of strings or text blocks
      then the first task text is returned
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

Adapter: hook-execute (src: src/lib/hook-execute.ts, src/lib/entry-input.ts; adapter: src/lib/hook-execute.adapter.test.ts; system: test/system/hook-sync.system.test.mjs)

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
    when no file_path is provided
      then deleted tracked files are detected
      and modified tracked files are detected
      and unresolved paths retaining conflict markers or matching a conflict side are excluded from detected resolved paths
      and permission-only changes are detected
      and untracked new files are detected (files created by Bash/apply_patch)
      and gitignored untracked files are excluded
    when a file_path is provided
      then working-tree detection (modified and untracked) is skipped (file_path mode is exclusive)

  getRuntimeContext
    then the host machine's hostname is reported

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
      when commit metadata and changed paths contain shell syntax or Git pathspec magic
        then they are passed literally to Git
        and no shell expression is evaluated
    when action is commit-merge
      then the merge is completed
      and the commit records session and agent provenance
      when Codex resolves conflicts without a file_path
        then every detected resolved path is staged and the merge is completed
        if only some of multiple conflicted files are resolved
          then only the resolved paths are staged
          and the merge remains open with the other paths unmerged
        if a markerless modify/delete conflict has not been edited
          then the path remains unmerged and no merge commit is created
      when Claude sends a file_path that retains conflict markers or is otherwise unconfirmed
        then the path remains unmerged and marker-neutral guidance is returned
      when the resolution is already staged
        then the merge is completed without requiring a file_path
    if the merge is unresolved
      then the git exit code is returned

  executeSync
    when called from a checked-out branch with a remote configured
      then the remote is checked for that branch
      and an existing branch is pulled before the current branch is pushed to its remote counterpart
    when the checked-out branch differs from another local branch
      then sync does not merge that other branch into the checked-out branch
    when push is rejected
      then exactly one pull-and-push retry is attempted
      when the current branch was created remotely after the initial pull
        then that branch is pulled before the retry push
    if the retried push also fails
      then exit 2 is returned with safe push-failure feedback
      and the feedback asks the agent to retry after the underlying condition is corrected without prescribing Git writes
      and Git's own output is wrapped in a tag marking its advice as not to be followed
    if pull produces a merge conflict
      when Git reports unmerged paths
        then exit 2 is returned with conflict feedback
        and the feedback uses tool-neutral file-edit guidance
        and Git's own output is wrapped in a tag marking its advice as not to be followed
    if pull fails without unmerged paths
      then exit 2 is returned with generic remote-failure feedback
      and no conflict markers are claimed
      and Git's own output is wrapped in a tag marking its advice as not to be followed
      and Git's suggestion to commit or stash the blocking changes is explicitly countermanded
    if Git cannot inspect unmerged paths after a pull failure
      then the inspection failure is propagated
    if the checked-out branch does not exist on the remote yet
      then the pull is skipped and the push creates it — no conflict is reported
    if no branch is checked out
      then sync fails before pulling or pushing and identifies that a branch must be checked out

  clockIn
    when timecard data is provided
      then the timeclock directory is created and a valid presence-only timecard is written
    when a timecard already exists for this session
      then clockedInAt is preserved across updates
      and lastActiveAt is bumped to now — the heartbeat that marks the agent recently alive
    if the session id is not a safe filename component
      then clock-in fails without writing outside the timeclock directory

  readTimecards
    when the timeclock directory does not exist
      then an empty list is returned
    when the directory contains multiple timecards
      then all are read
    if a timecard file has invalid JSON, missing, empty, or wrongly typed identity fields, an invalid timestamp, an unsafe session id, or an id that differs from its filename
      then reading fails and identifies the malformed file

  reapCards
    when given the session ids classified reapable
      then each card file is removed and its path is returned
    when a timecard file is already gone
      then it is handled gracefully
    if a session id is not a safe filename component
      then reaping fails without removing anything outside the timeclock directory

  executePlan with timecard touch
    when a commit fires and the session already has a timecard
      then lastActiveAt is updated and committed alongside the code change
    when a commit fires and the session has no timecard
      then no timecard is created
    if the existing session timecard is malformed
      then the commit fails and identifies the malformed timecard
    when a trunk-sync conflict happens and other agents are active
      then exit 2 includes the conflict feedback and the active roster
    when another agent's card is older than the reap ttl
      then it is reaped as part of the same commit
      if the classified card disappears before its path can be staged
        then no unrelated repository path is staged
    when another agent's card is within the reap ttl
      then it is preserved, not reaped

  runSessionStart
    when the session-start hook fires
      then the starting agent's timecard is created and synced
      and every other session's timecard is read and classified by heartbeat age, the starting session excluded
      and unrelated staged or unstaged source and timecard changes remain uncommitted
      when active cards are present
        then active cards are appended to coordinate around automatic session presence
      when only stale cards are present
        then no session-start context is emitted because stale cards are not session summaries
      when only reapable cards (or none) remain
        then no session-start context is emitted
    if the clock-in commit fails
      then the hook reports that presence is local-only with the commit failure
    if clock-in sync fails
      then the hook reports that presence is local-only with the sync failure
    if the timeclock directory does not exist
      then it is created for the starting session and the hook exits 0
    if no session id is provided
      then no timecard is created and nothing is printed
    if no branch is checked out
      then no timecard is created and branch guidance is returned

  runStop
    when the stop hook fires and the session has a timecard
      then its timecard is removed and the removal is synced, automatically clocking the session out
      and it always exits 0
    if the clock-out commit fails
      then the hook still exits 0
      and warns that the remote may still show the session as active with the commit failure
    if clock-out sync fails
      then the hook still exits 0
      and warns that the remote may still show the session as active with the sync failure
    if the session has no timecard yet
      then it exits 0 without creating one — a session that never edited has no timecard to clock out
    if no session id is provided
      then it exits 0 without action
    if clock-out cannot read or remove the timecard
      then it still exits 0 with a stale-remote warning
```

## Adapter: hook-entry

```
Adapter: hook-entry (src: src/lib/entry-input.ts, src/lib/hook-entry.ts, src/lib/pre-tool-entry.ts, src/lib/session-start-entry.ts, src/lib/stop-entry.ts; adapter: src/lib/hook-entry.adapter.test.ts)

  when PostToolUse receives empty or missing-event stdin in a dirty repository
    then it exits 0 without committing or staging the unrelated changes
  when PostToolUse Edit or Write is missing a usable file_path in a dirty repository
    then it exits 2 with input-error feedback
    and no repository state is changed
  when PostToolUse Edit or Write provides a whitespace-only or NUL-containing file_path in a dirty repository
    then it exits 2 with input-error feedback
    and no repository state is changed
  when any hook entrypoint receives syntactically malformed or structurally invalid JSON in a dirty repository
    then it exits 2 with input-error feedback
    and no repository state is changed
  if SessionStart or Stop receives an inaccessible cwd
    then it exits 2 with input-error feedback
    and no repository state is changed
  if SessionStart or Stop receives an unsafe session id
    then it exits 2 with input-error feedback
    and no repository state is changed
```

## Adapter: command-guard

```
Adapter: command-guard (src: src/lib/pre-tool-entry.ts; adapter: src/lib/pre-tool-entry.adapter.test.ts; system: test/system/hook-sync.system.test.mjs; journey: test/journey/agent-hook-compatibility.journey.test.sh)

  when Claude Code sends a Bash command as a string
    then the command is classified and its decision is returned as the hook exit
  when Codex sends a local_shell command as an array
    then the command is classified and its decision is returned as the hook exit
  when the command is rejected
    then exit 2 and guidance that inspection is allowed and trunk-sync owns git writes are written to stderr
    and shell command-string wrappers, eval, command-position substitutions, and command-position parameter expansions cannot bypass the guard
  when the command is allowed
    then exit 0 is returned without feedback
```

## Domain: command-guard

```
Domain: command-guard (src: src/lib/command-guard.ts; domain: src/lib/command-guard.domain.test.ts; adapter: src/lib/pre-tool-entry.adapter.test.ts; system: test/system/hook-sync.system.test.mjs; journey: test/journey/agent-hook-compatibility.journey.test.sh)

  classifyCommand
    when a command contains no recognized Git invocation
      then it is allowed, including compound shell commands
    when standalone git clone or a standalone git command only inspects repository, worktree, or history state
      then it is allowed, including with read-only global and subcommand options
    if a Git invocation is composed with another shell command
      then it is rejected with guidance to run standalone Git inspection
      and shell command-string wrappers with absolute paths or combined options, `eval`, escaped or quoted executable spellings, quoted assignment prefixes, executable command-position expansion, and substitutions inside Git arguments are rejected
    if a git command can change repository, worktree, configuration, or remote state
      then it is rejected with guidance that inspection is allowed and trunk-sync owns git writes
```

## System: hook-sync

```
System: hook-sync (src: hooks/hooks.json; system: test/system/hook-sync.system.test.mjs; journey: test/journey/agent-hook-compatibility.journey.test.sh)

  every Edit/Write/Bash/apply_patch/local_shell tool use
    then the changed file is staged and committed
    and commits with a session record the session and originating agent provenance
    when a remote is configured
      then the checked-out branch is pulled from and pushed to its branch of the same name on the consumer repository
    when no remote is configured
      then push is silently skipped
  every Bash tool use
    when the command contains no Git invocation
      then it is allowed through
    when the command is standalone git clone or only standalone Git inspection
      then it is allowed through
    if a Git invocation is composed with another shell command
      then it is rejected with feedback directing the agent to run inspection as a standalone Git command
      and shell command-string wrappers with absolute paths or combined options, `eval`, escaped executable, quoted assignment, command-position expansion, and nested substitution bypasses are rejected
    if the git command can change repository, worktree, configuration, or remote state
      then it is rejected with feedback directing the agent to edit files and leave git writes to trunk-sync
  every local_shell tool use
    when the command is standalone git clone or only standalone Git inspection
      then it is allowed through
    if a Git invocation is composed with another shell command
      then it is rejected with feedback directing the agent to run inspection as a standalone Git command
    if the git command can change repository, worktree, configuration, or remote state
      then it is rejected with the same feedback as Bash
  every session start from a checked-out branch
    then the starting agent is clocked in without adding its own internal session id to agent context
    when other sessions have stale cards
      then they are omitted because timecards represent presence, not session summaries
    when other sessions have active cards
      then that recently-alive work is surfaced to coordinate around
    when only reapable cards remain
      then no session-start context is emitted
    if clock-in cannot be pushed
      then local presence is retained and a local-only warning is reported
  every end of task
    then the agent's timecard is removed and synced, automatically clocking the session out for remote readers
    and the agent is never forced to act — the stop hook always exits 0
    if clock-out cannot be pushed
      then the local removal is committed and stale-remote warning is reported
  when an agent is disrupted mid-task and a new session starts
    then the disrupted agent's stale card is omitted
  when a merge conflict arises during sync
    then exit 2 surfaces self-contained conflict-resolution instructions
    and active timecards are surfaced again to coordinate around ongoing sessions
    when the agent edits the conflicted file and the hook fires again
      then the merge is completed
    when Claude edits a conflicted file but leaves conflict markers or otherwise remains unconfirmed
      then the path remains unmerged and no merge commit or push occurs
    when Codex resolves the conflicted file through apply_patch without a file_path
      then the resolved path is staged and the merge is committed and pushed with Codex provenance
  when a push is rejected
    then the bare remote observes exactly two push attempts and the retry succeeds
```

## Journey: agent-hook-compatibility

```
Journey: agent-hook-compatibility (src: test/journey/claude-openai-responses-proxy.mjs, test/journey/docker-run.sh, test/journey/prepare-checkout-topology.sh, test/journey/agent-hook-compatibility.journey.test.sh; journey: test/journey/source-plugin-compatibility.journey.test.sh)

  when the functional journey is launched with OPENAI_API_KEY
    then OpenAI-backed model access is available to the selected agent harness
      when Claude Code loads the source plugin bundle directly in a checked-out consumer repository
        if it attempts a write-side git command
          then the command is rejected with instructions to edit file content instead
        if it composes Git inspection with another shell command
          then the command is rejected with standalone inspection guidance
        when it uses the native Write tool after the rejections
          then the transcript records the native tool use
          then the edit is committed and pushed to the current branch in the consumer repository
          and the commit records the Claude session and agent provenance
        when the session starts and ends
          then clock-in and clock-out commits are retained in remote history
        when the session ends
          then its presence is removed from the current branch

      when Codex loads the source plugin bundle directly in a checked-out consumer repository
        if it attempts a write-side git command
          then the command is rejected with instructions to edit file content instead
        if it composes Git inspection with another shell command
          then the command is rejected with standalone inspection guidance
        when it uses the native apply_patch tool after the rejections
          then the transcript records the native tool use
          then the edit is committed and pushed to the current branch in the consumer repository
          and the commit records the Codex session and agent provenance
        when the session starts and ends
          then clock-in and clock-out commits are retained in remote history
        when the session ends
          then its presence is removed from the current branch
```

## Journey: installed-plugin-compatibility

```
Journey: installed-plugin-compatibility (src: test/journey/claude-openai-responses-proxy.mjs, test/journey/docker-run.sh, test/journey/prepare-checkout-topology.sh, test/journey/agent-hook-compatibility.journey.test.sh; journey: test/journey/installed-plugin-compatibility.journey.test.sh)

  when the release/install journey is launched with OPENAI_API_KEY
    then OpenAI-backed model access is available to the selected agent harness
      when the repository marketplace is added and trunk-sync is installed
        then the host discovers the installed plugin from its cache
      when Claude Code uses trunk-sync installed through its plugin manager in a checked-out consumer repository
        if it attempts a write-side git command
          then the command is rejected with instructions to edit file content instead
        if it composes Git inspection with another shell command
          then the command is rejected with standalone inspection guidance
        when it uses the native Write tool after the rejections
          then the transcript records the native tool use
          then the edit is committed and pushed to the current branch in the consumer repository
          and the commit records the Claude session and agent provenance
        when the session starts and ends
          then clock-in and clock-out commits are retained in remote history
        when the session ends
          then its presence is removed from the current branch

      when Codex uses trunk-sync installed through its plugin manager in a checked-out consumer repository
        if it attempts a write-side git command
          then the command is rejected with instructions to edit file content instead
        if it composes Git inspection with another shell command
          then the command is rejected with standalone inspection guidance
        when it uses the native apply_patch tool after the rejections
          then the transcript records the native tool use
          then the edit is committed and pushed to the current branch in the consumer repository
          and the commit records the Codex session and agent provenance
        when the session starts and ends
          then clock-in and clock-out commits are retained in remote history
        when the session ends
          then its presence is removed from the current branch
```

## Adapter: hook-registration

```
Adapter: hook-registration (src: hooks/hooks.json; adapter: src/lib/hook-registration.adapter.test.ts)

  when trunk-sync is loaded by an agent host
    then Bash and local_shell commands are guarded before execution
    and Edit, Write, Bash, apply_patch, and local_shell changes trigger synchronization
    and session start and stop trigger their lifecycle entries
```

## Adapter: plugin-version-bump

```
Adapter: plugin-version-bump (src: scripts/bump-plugin-manifests.js; adapter: test/adapter/plugin-version-bump.adapter.test.mjs)

  when a release bump runs
    when the bump is patch, minor, or major
      then the Claude Code and Codex plugin manifests advance together from their shared version
      and numeric components advance without precision loss
  if the Claude Code or Codex plugin manifest is missing
    then the bump fails without modifying the existing manifest
  if the plugin manifests have different versions
    then the bump fails without modifying either manifest
  if the shared version is not a canonical three-number semantic version
    then the bump fails without modifying either manifest
  if either bumped manifest cannot be written
    then the bump fails and both manifests retain their original contents
```
