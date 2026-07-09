## Core Domain Identity

- trunk-sync keeps multiple agents in continuous integration on a shared branch via a post-edit git hook, plus a separate CLI for seance and config.
- Two independent layers share one repo: a Claude Code / Codex hook (auto commit/pull/push + timecards) and a TypeScript CLI.
- Conflicts are surfaced as hook feedback for the agent to resolve in file content; the hook completes the merge on the next fire — agents never run git themselves.
- Every commit is provenance-stamped so any line can be traced back to the conversation that wrote it (seance).
- Agents register presence via committed, heartbeat-timestamped timecards, giving cross-machine visibility of who is clocked in.

## World-to-Code Mapping

- Pure decision logic → `hook-plan.ts`; git/fs execution → `hook-execute.ts`; PostToolUse wiring → `hook-entry.ts`; SessionStart wiring → `session-start-entry.ts`; bash wrappers → `scripts/trunk-sync*.sh`.
- CLI commands → `src/commands/{seance,config}.ts`; shared git utilities → `src/lib/git.ts`.
- A line of code → `git blame` → commit-body provenance → truncated transcript → worktree at that commit → resumed agent session (seance).
- "Who is active" → `.trunk-sync/timeclock/<session-id>.json` (heartbeat `lastActiveAt`, branch), committed and pushed; surfaced at SessionStart while active.
- Trunk → `origin/agents` by default (`.trunk-sync/config`'s `target-branch` key overrides); worktree → optional isolation for multi-agent (`claude -w`).
- Distribution → `dist/` tracked in git (marketplace installs) + an npm tarball selected by the `files` field.

## Ubiquitous Language

- Trunk — `origin/agents` by default, the shared integration branch kept separate from the repo's actual default branch; overridable via the `target-branch` key in `.trunk-sync/config`.
- Hook layer — fires on Edit/Write/Bash (stage, commit, pull, push) and on SessionStart (surface timecards).
- CLI layer — `trunk-sync seance | config`.
- Seance — reconstruct and resume the agent session behind a line of code; modes default / `--inspect` / `--list`.
- Session ID — links a commit to a Claude/Codex conversation.
- Provenance fields — `Session:`, `Agent:`, `TranscriptPath:` in the commit body.
- Timecard — `.trunk-sync/timeclock/<id>.json`; who is clocked in, where, and when its heartbeat was last refreshed.
- Liveness — the age of a card's heartbeat (`lastActiveAt`): active within the hour, stale beyond it, reapable past a 14-day TTL. No PID — the first edit creates the card, and the Stop hook removes it.
- Worktree — optional isolated working tree for multi-agent runs.
- Conflict feedback — exit 2 with a stderr message; the agent fixes file content only.

## Bounded Contexts

- Hook (continuous integration) — the auto commit/pull/push loop and conflict surfacing.
- Seance — provenance-driven session reconstruction and resume.
- Timeclock — cross-machine agent presence and resource-conflict signalling.
- Config — the `.trunk-sync/config` key=value store in the repo, committed and synced like timecards.

## Invariants

- The hook owns all git operations during a sync; agents only edit files, never run git.
- Conflicts are resolved by editing file contents; the hook completes the merge on the next fire.
- Every commit carries `Session:` and `Agent:`; `TranscriptPath:` is added when the payload provides one.
- `dist/` is committed (minus tests and `.d.ts`) because marketplace installs run the compiled hook.
- Pure logic is unit-tested; git/fs callers use real temp repos — never mocks for git.
- Every exported function ships with tests in the same PR.
- Hook exit codes: 0 = success/no-op, 2 = conflict/failure with agent feedback on stderr.
- npm and `.claude-plugin/plugin.json` versions stay in lockstep via the `version` lifecycle script.

## Decision Rationale

- The hook handles git so agents stay focused on content and never corrupt the shared branch with ad-hoc git.
- The functional-core / imperative-shell split keeps decision logic pure and fast to unit-test.
- Seance finds Codex rollouts by scanning `~/.codex/sessions/<date>/`; placing a rewritten rollout at the canonical path is sufficient — no DB insertion, do not add it.
- Timecards and config are committed (not local-only) so presence and settings are visible across every machine and agent working on the repo — same reasoning for both. Liveness is the heartbeat's age, not a PID — the hook runs as an ephemeral process, so a stored PID is never the agent's; remote liveness can only ever be presumed from the heartbeat, and failing tests are the authoritative WIP signal.
- Agents default to a dedicated `agents` branch, not the repo's actual default branch, so per-edit auto-commits never land directly on it — merging agent work into the real default branch stays a deliberate, separate step.
- Timecards stay limited to presence; handover belongs in tests, transcripts, or conversation, not the timeclock.
- `dist/` is tracked because marketplace installs have no build step.
- The two distribution channels (npm + marketplace) are bumped together to avoid version skew. The npm CLI and agent plugin are separate install surfaces; the CLI never installs or manages the plugin.

## Temporal View

- Per edit: stage → commit (provenance + timecard) → pull the target branch (`origin/agents` by default) → push; on conflict, exit 2 → agent edits → next fire completes the merge.
- First edit of a session: nudge the agent to run the tests — failing tests are the authoritative signal of unfinished WIP, resumable when not owned by an active agent; the cards are advisory context.
- Throttled (≤ once / 5 min): surface other active agents so the agent can reason about shared resources.
- At session start: the SessionStart hook hands the agent its session id and surfaces active sessions' timecards so the agent can coordinate around shared resources.
- End of session: the Stop hook removes and syncs the session's timecard, automatically clocking the agent out; it never forces the agent.
- Reaping: any card whose heartbeat is older than the 14-day TTL, swept on the next agent's commit.
- Seance, on demand: blame → provenance → transcript truncation → worktree → resume.
- Release: bump both manifests → build → `pnpm publish` (npm) → push to GitHub (marketplace).
