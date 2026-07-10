## Core Domain Identity

- trunk-sync keeps multiple agents in continuous integration on a shared branch via Claude Code / Codex hooks.
- The hook layer owns auto commit/pull/push and timecards.
- Conflicts are surfaced as hook feedback for the agent to resolve in file content; the hook completes the merge on the next fire — agents never run git themselves.
- Every commit with a session carries `Session:` and `Agent:` provenance.
- Agents register presence via committed, heartbeat-timestamped timecards, giving cross-machine visibility of who is clocked in.

## World-to-Code Mapping

- Pure decision logic → `hook-plan.ts`; git/fs execution → `hook-execute.ts`; PostToolUse wiring → `hook-entry.ts`; SessionStart wiring → `session-start-entry.ts`; bash wrappers → `scripts/trunk-sync*.sh`.
- "Who is active" → `.trunk-sync/timeclock/<session-id>.json` (heartbeat `lastActiveAt`, branch), committed and pushed; surfaced at SessionStart while active.
- Trunk → `origin/agents` by default, overridden per repository by `.trunk-sync/config`'s `target-branch`; worktree → optional isolation for multi-agent (`claude -w`).
- Distribution → `dist/` tracked in git because marketplace installs from compiled hook files.

## Ubiquitous Language

- Trunk — `origin/agents` by default, the shared integration branch kept separate from the repo's actual default branch; `.trunk-sync/config`'s `target-branch` can opt a repository into another branch.
- Hook layer — fires on SessionStart (create/sync own timecard + surface active timecards), Edit/Write/Bash (stage, commit, pull, push), and Stop (remove/sync own timecard).
- Session ID — links a commit to a Claude/Codex conversation.
- Provenance fields — `Session:` and `Agent:` in the commit body.
- Timecard — `.trunk-sync/timeclock/<id>.json`; who is clocked in, where, and when its heartbeat was last refreshed.
- Liveness — the age of a card's heartbeat (`lastActiveAt`): active within the hour, stale beyond it, reapable past a 14-day TTL. No PID — SessionStart creates the card, writes refresh it, and Stop removes it.
- Worktree — optional isolated working tree for multi-agent runs.
- Conflict feedback — exit 2 with a stderr message; the agent fixes file content only.

## Bounded Contexts

- Hook (continuous integration) — the auto commit/pull/push loop and conflict surfacing.
- Timeclock — cross-machine agent presence and resource-conflict signalling.

## Invariants

- The hook owns all git operations during a sync; agents only edit files, never run git.
- Conflicts are resolved by editing file contents; the hook completes the merge on the next fire.
- Every commit with a session carries `Session:` and `Agent:`.
- `dist/` is committed (minus tests and `.d.ts`) because marketplace installs run the compiled hook.
- Pure logic is unit-tested; git/fs callers use real temp repos — never mocks for git.
- Every exported function ships with tests in the same PR.
- Hook exit codes: 0 = success/no-op, 2 = conflict/failure with agent feedback on stderr.
- `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` versions stay in lockstep through the release bump.

## Decision Rationale

- The hook handles git so agents stay focused on content and never corrupt the shared branch with ad-hoc git.
- The functional-core / imperative-shell split keeps decision logic pure and fast to unit-test.
- Timecards are committed, not local-only, so presence is visible across every machine and agent working on the repo. Liveness is the heartbeat's age, not a PID — the hook runs as an ephemeral process, so a stored PID is never the agent's; remote liveness can only ever be presumed from the heartbeat, and failing tests are the authoritative unfinished-work signal.
- Agents default to a dedicated `agents` branch so per-edit auto-commits do not land directly on the repo's actual default branch; repositories can deliberately choose another target with `.trunk-sync/config`.
- Timecards stay limited to presence; handover belongs in tests, transcripts, or conversation, not the timeclock.
- `dist/` is tracked because marketplace installs have no build step.
- Both plugin manifests are bumped together to avoid version skew between agent harnesses.

## Temporal View

- At session start: the SessionStart hook creates and syncs the agent's timecard and surfaces other active sessions' timecards so the agent can coordinate around shared resources.
- Per edit: stage → commit (provenance + refreshed timecard when one exists) → pull the configured target branch (`origin/agents` by default) → push; on conflict, exit 2 with active timecards included → agent edits → next fire completes the merge.
- End of session: the Stop hook removes and syncs the session's timecard, automatically clocking the agent out; it never forces the agent.
- Reaping: any card whose heartbeat is older than the 14-day TTL, swept on the next agent's commit.
- Release: choose a semantic version change kind → bump both plugin manifests → tag → push to GitHub → create the GitHub release.
