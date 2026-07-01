## Core Domain Identity

- trunk-sync keeps multiple agents in continuous integration on `origin/main` via a post-edit git hook, plus a CLI for install / seance / config.
- Two independent layers share one repo: a Claude Code hook (auto commit/pull/push) and a TypeScript CLI.
- Conflicts are surfaced as hook feedback for the agent to resolve in file content; the hook completes the merge on the next fire — agents never run git themselves.
- Every commit is provenance-stamped so any line can be traced back to the conversation that wrote it (seance).
- Agents register presence via committed, heartbeat-timestamped timecards and record handover progress (last step + remaining steps) in them, giving cross-machine visibility of who is working on what and where they left off.

## World-to-Code Mapping

- Pure decision logic → `hook-plan.ts`; git/fs execution → `hook-execute.ts`; PostToolUse wiring → `hook-entry.ts`; SessionStart wiring → `session-start-entry.ts`; bash wrappers → `scripts/trunk-sync*.sh`.
- CLI commands → `src/commands/{install,seance,config}.ts`; shared git utilities → `src/lib/git.ts`.
- A line of code → `git blame` → commit-body provenance → truncated transcript → worktree at that commit → resumed agent session (seance).
- "Who is clocked in" + handover → `.trunk-sync/timeclock/<session-id>.json` (branch, task, lastStep, remainingSteps), committed and pushed; progress set by `trunk-sync progress`, surfaced at SessionStart.
- Trunk → always `origin/main`; worktree → optional isolation for multi-agent (`claude -w`).
- Distribution → `dist/` tracked in git (marketplace installs) + an npm tarball selected by the `files` field.

## Ubiquitous Language

- Trunk — `origin/main`, the shared integration branch.
- Hook layer — fires on Edit/Write/Bash (stage, commit, pull, push) and on SessionStart (surface handovers).
- CLI layer — `trunk-sync install | seance | config`.
- Seance — reconstruct and resume the agent session behind a line of code; modes default / `--inspect` / `--list`.
- Session ID — links a commit to a Claude/Codex conversation.
- Provenance fields — `Session:`, `Agent:`, `TranscriptPath:` in the commit body.
- Timecard — `.trunk-sync/timeclock/<id>.json`; who is clocked in, on what, and their handover (last step + remaining steps).
- Handover — the last step + remaining steps an agent records in its timecard via `trunk-sync progress`, surfaced to the next session at SessionStart; advisory context, reaped only past the 14-day TTL (the committed transcript is the durable record).
- Liveness — the age of a card's heartbeat (`lastActiveAt`): active within the hour, stale (possibly disrupted) beyond it, reapable past a 14-day TTL. No PID and no clock-out command — the first edit creates the card, `trunk-sync progress` records the handover.
- Worktree — optional isolated working tree for multi-agent runs.
- Conflict feedback — exit 2 with a stderr message; the agent fixes file content only.
- Install scope — project by default, `--scope user` for all repos, `--client codex` for the Codex marketplace path.

## Bounded Contexts

- Hook (continuous integration) — the auto commit/pull/push loop and conflict surfacing.
- CLI install — marketplace registration + plugin install across Claude Code and Codex.
- Seance — provenance-driven session reconstruction and resume.
- Timeclock — cross-machine agent presence, resource-conflict signalling, and cross-session handover.
- Config — the `~/.trunk-sync` key=value store.

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
- Timecards are committed (not local-only) so presence is visible across machines.
- Handover progress is agent-authored via `trunk-sync progress` — transcript prose can't reliably yield last/next — and lives in the ephemeral timecard; transcripts commit by default so seance and handover always have the record.
- `dist/` is tracked because marketplace installs have no build step.
- The two distribution channels (npm + marketplace) are bumped together to avoid version skew.

## Temporal View

- Per edit: stage → commit (provenance + timecard) → pull `origin/main` → push; on conflict, exit 2 → agent edits → next fire completes the merge.
- First edit of a session: nudge the agent to run the tests — failing tests are the authoritative signal of unfinished WIP, resumable when not owned by an active agent; the cards are advisory context.
- Throttled (≤ once / 5 min): surface other active agents so the agent can reason about shared resources.
- At session start: the SessionStart hook hands the agent its session id and surfaces other sessions' handovers — active to coordinate around, stale (possibly disrupted) to verify-and-resume — so work continues across sessions.
- End of every turn: a Stop hook bumps the heartbeat (and re-syncs it when stale) so a busy-but-quiet agent stays visible to remote readers; it never forces the agent.
- Reaping: any card whose heartbeat is older than the 14-day TTL, swept on the next agent's commit — uniform, regardless of remaining work (the committed transcript is the durable record).
- Seance, on demand: blame → provenance → transcript truncation → worktree → resume.
- Release: bump both manifests → build → `pnpm publish` (npm) → push to GitHub (marketplace).
