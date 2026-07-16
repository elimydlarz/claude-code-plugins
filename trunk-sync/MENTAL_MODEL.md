## Core Domain Identity

- trunk-sync keeps agents sharing a branch in continuous integration via Claude Code / Codex hooks.
- The hook layer owns auto commit/pull/push and timecards.
- Conflicts are surfaced as hook feedback for the agent to resolve in file content; the hook completes the merge on the next fire — agents use standalone Git inspection and leave write-side Git operations to the hook.
- File-change commits with a session carry `Session:` and `Agent:` provenance.
- Agents register presence via committed, heartbeat-timestamped timecards, giving cross-machine visibility of who is clocked in through synchronized branch content.

## World-to-Code Mapping

- Hook input validation → `entry-input.ts`; hook planning → `hook-plan.ts`; command classification → `command-guard.ts`; git/fs execution → `hook-execute.ts`; PreToolUse wiring → `pre-tool-entry.ts`; PostToolUse wiring → `hook-entry.ts`; SessionStart wiring → `session-start-entry.ts`; Stop wiring → `stop-entry.ts`; bash wrappers → `scripts/trunk-sync*.sh`.
- "Who is active" → `.trunk-sync/timeclock/<session-id>.json` (heartbeat `lastActiveAt`, branch), committed locally and synchronized through `origin` when available; surfaced at SessionStart while active.
- Trunk → the checked-out branch and its remote counterpart; same-branch collaborators use independent clones.
- Distribution → `dist/` tracked in git because marketplace installs from compiled hook files.

## Ubiquitous Language

- Trunk — the branch currently checked out by the agent and its same-named branch at `origin`.
- Hook layer — allows standalone inspection and clone, rejects composed inspection and repository-mutating Git commands on PreToolUse, and owns synchronization on SessionStart, Edit/Write/Bash/apply_patch/local_shell, and Stop.
- Session ID — links a file-change commit to a Claude/Codex conversation.
- Provenance fields — `Session:` and `Agent:` in the commit body.
- Timecard — `.trunk-sync/timeclock/<id>.json`; who is clocked in, where, and when its heartbeat was last refreshed. Its filename and `sessionId` agree as one safe filename component; malformed cards fail visibly.
- Liveness — the age of a card's heartbeat (`lastActiveAt`): active within the hour, stale beyond it, reapable past a 14-day TTL. No PID — SessionStart creates the card, writes refresh it, and Stop removes it.
- Checkout topology — agents converge through independent clones that isolate in-progress files and Git state.
- Conflict feedback — exit 2 with a stderr message; the agent fixes file content only.

## Bounded Contexts

- Hook (continuous integration) — write-side Git command ownership, the auto commit/pull/push loop, and conflict surfacing.
- Timeclock — cross-machine agent presence for coordinating shared resources.

## Invariants

- The hook owns repository-mutating Git operations during a sync; agents may clone and inspect repository, worktree, and history state with standalone Git commands.
- Command guarding, native file synchronization, provenance, and session presence behave consistently across collaborator clones.
- Conflicts are resolved by editing file contents; after every changed path is confirmed resolved, the hook completes the merge on the next fire.
- Every file-change commit with a session carries `Session:` and `Agent:`.
- `dist/` is committed (minus tests and `.d.ts`) because marketplace installs run the compiled hook.
- Pure logic is unit-tested; git/fs callers use real temp repos — never mocks for git.
- Every exported function ships with tests in the same PR.
- Hook exit codes: 0 = success/no-op; 2 = rejected commands, input errors, verified-unresolved paths, and sync failures with agent feedback; an unexpected Git commit failure returns Git's exit code.
- `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` versions stay in lockstep through the release bump.

## Decision Rationale

- The hook handles Git writes so agents stay focused on content while standalone read-only inspection remains available for understanding what happened.
- The functional-core / imperative-shell split keeps decision logic pure and fast to unit-test.
- Timecards are committed, not local-only, so presence travels with synchronized branch content across machines. Liveness is the heartbeat's age, not a PID — the hook runs as an ephemeral process, so a stored PID is never the agent's; remote liveness can only ever be presumed from the heartbeat, and failing tests are the authoritative unfinished-work signal.
- Synchronizing the checked-out branch avoids merging history from an unrelated local or remote integration branch into the agent's working tree.
- Independent clones isolate in-progress files and Git state while the same-named remote branch provides convergence.
- Timecards stay limited to presence; handover belongs in tests, transcripts, or conversation, not the timeclock.
- `dist/` is tracked because marketplace installs have no build step.
- Both plugin manifests are bumped together to avoid version skew between agent harnesses.

## Temporal View

- At session start: the SessionStart hook creates and syncs the agent's timecard and surfaces other active timecards visible in the checkout so the agent can coordinate around shared resources.
- Per edit: stage → commit (provenance + refreshed timecard when one exists) → pull the checked-out branch from `origin` → push that branch; on conflict, exit 2 with active timecards included → agent edits → next fire completes the merge.
- End of session: the Stop hook removes and syncs the session's timecard, automatically clocking the agent out; it never forces the agent.
- Reaping: any card whose heartbeat is older than the 14-day TTL, swept on the next agent's commit.
- Release: choose a semantic version change kind → build the tracked marketplace runtime → bump both plugin manifests → commit the runtime and manifests → tag → atomically push the branch and tag; if either ref is rejected, restore the pre-release local commit, tag, runtime, manifests, and index so the same bump can be retried; after a successful push, create the GitHub release.
