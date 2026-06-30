# PROGRESS_PLAN.md — trunk-sync cross-session handover feature

Handoff for an agent starting in a fresh context window. Read this top to bottom; it is self-contained.

## The task

Add **cross-session handover** to trunk-sync: agents record their progress in their timecard, and a new session discovers other sessions' unfinished work and can resume it. The hard problem is **telling work-in-progress apart from work that was disrupted** (both leave a timecard, possibly with a progress update).

## Where things stand — READ THIS FIRST

We are mid-`change`: **the timecard test trees in `TEST_TREES.md` have been rewritten to a new design, but the CODE still implements the OLD design.** Trees are deliberately ahead of code. Do **not** treat the current code as the contract — the trees are. Do not "fix" this drift by reverting trees.

Two designs exist:

- **Option A (currently IMPLEMENTED, shipped, tested):** ephemeral handover. The `progress` command writes `lastStep`/`remainingSteps` into a timecard; SessionStart surfaces every other session's card; cards are reaped by the old liveness rules. Works only for "switch sessions immediately." Its weaknesses (can't tell WIP from disrupted; deletes unfinished work; no clearing) are exactly what the rewrite fixes.
- **New design (in the trees now, NOT yet implemented):** an explicit `active / disrupted / done` state model with `clockin`/`clockout` commands and a **Stop hook** that heartbeats + forces progress updates.

## The new design (agreed with the user)

1. **Timecards keyed by `session_id`.** Every hook (PostToolUse, SessionStart, and the new Stop) receives `session_id` on stdin (Claude AND Codex — confirmed), so hooks locate/update the right card with no agent cooperation. Path: `.trunk-sync/timeclock/<session-id>.json`.
2. **A Stop hook fires at every end of task** — it bumps the heartbeat (`lastActiveAt`) and forces the agent to record progress (or `clockout`). The heartbeat is the liveness signal: a live agent keeps emitting; a disrupted one goes silent.
3. **Explicit `clockin`/`clockout` bracket the task**, but the edit/stop hook **ensures a card exists** as a passive fallback, so an agent that forgets is still visible.

**The state model (`classifyTimecards`)** — liveness is determined differently per location, then crossed with remaining-work:

| determination | result |
|---|---|
| local + live PID | live, **certain** |
| local + dead PID | ended, **certain** |
| remote + heartbeat within window | live, **presumed** (no remote PID to check) |
| remote + heartbeat past window | ended, **presumed** |

| has remaining work? | live? | state | discovery says |
|---|---|---|---|
| yes | live | **active** | coordinate, don't duplicate |
| yes | ended | **disrupted** | resume this handover |
| no | live | **done, kept** | agent may take another task |
| no | ended | **done, reapable** | reap it |

Reaping: **never reap unfinished work**; reap only `done + reapable`. `clockout` clears `remainingSteps` → makes a card done/reapable.

## OPEN DECISIONS — these block finishing the trees

- **A — how does a disrupted card ever get cleared?** Exemption-from-reaping was added, but nothing clears an abandoned/resumed disrupted card: the resumer has a *different* `session_id`, so it makes its own card and never clears the one it resumed → **disrupted cards accumulate forever.** Proposed (unconfirmed): instruct the resumer to run `trunk-sync clockout <resumed-id>` when done, **plus** a long-TTL backstop (e.g. reap even disrupted cards after ~7 days). NEEDS USER DECISION.
- **D — the remote staleness window value.** It must **exceed the longest tolerated task turn**, or a busy remote agent between Stop-hook beats is misread as disrupted and its work gets duplicated. (Local is safe — PID covers long turns.) Old value was 30 min, likely too short. NEEDS USER DECISION.

## Audit fixes to apply to the trees (shape agreed, awaiting a "go")

- **B** — split `disrupted` into **certain** (local dead PID) vs **presumed** (remote stale heartbeat), mirroring the `active` split. A presumed-disrupted remote card might still be alive behind a partition; resuming it risks duplication. (I split `active` but left `disrupted` as one case — asymmetric, wrong.)
- **C** — `progress` partial-update footgun: `progress --last "x"` with no `--next` currently nulls `remainingSteps` → flips the card to done/reapable → **destroys the handover.** Define: update only the provided field. (The current option-A `progress.ts` has this bug.)
- **E** — reconcile the old first-clock-in "failing tests are WIP checkpoints" nudge with explicit disrupted cards (two overlapping WIP signals that can disagree).
- **F** — state the surface asymmetry deliberately: `formatClockInMessage` (mid-work) shows only **active**; `formatSessionStartSummary` (start) shows **active + disrupted**.
- **G** — fix vocabulary drift: `executePlan with clock-in` still says "other agents are **clocked in**" (old 2-state term) — make it active/disrupted/done.
- **H** — add a `Stop` entry to `hooks.json` and a path to the `dual-harness-compatibility` tree; confirm Codex's Stop payload includes `stop_hook_active` (needed for loop-prevention; Claude has it).

## Implementation plan (TDD, after trees are final)

trunk-sync uses test-first with **node:test** (unit/integration, real temp repos — no git mocks) + a **shell E2E** (`test/trunk-sync.test.sh`, TAP) + a **real-CLI Docker System test** (`test/functional/`). Three-layer rule. Build with `pnpm run build`; dist is tracked in git.

1. **Rewrite** `classifyTimecards` (2-state → 4-state local/remote split), `clockOutStale` (exemption), the formatters, `runSessionStart`.
2. **New** `src/lib/stop-entry.ts` + `scripts/trunk-sync-stop.sh` + a `Stop` entry in `hooks/hooks.json`; `src/commands/clockin.ts` + `src/commands/clockout.ts` (+ `.test.ts` each); wire both into `src/cli.ts`.
3. **Heartbeat** semantics: `clockIn` and `progress` bump `lastActiveAt`; the Stop hook bumps it every turn.
4. **Fix** the `progress` partial-update bug (C).
5. **Update** the existing 190 node + 122 shell E2E tests to the new model (the option-A tests for `runSessionStart`/`clockOutStale`/`classifyTimecards`/`formatSessionStartSummary` will change).
6. **Add** a `clockin → work → disrupt (kill the session) → resume` case to the Docker real-CLI System test (`test/functional/docker-entrypoint.sh`).
7. **Then** reconcile `MENTAL_MODEL.md` (active/disrupted/done ladder; heartbeat; Stop hook), `CLAUDE.md` Repo Map, and `README.md`.

## Key facts & gotchas (learned the hard way)

- **Transcript prose extraction of last/next does NOT work** — proven by a spike against real transcripts (zero TodoWrite usage; "last step" from narration is noise-dominated; "remaining" has no source). That's why progress is **agent-authored**, not derived. Do not revisit auto-extraction.
- **`commit-transcripts` now defaults ON** (opt out with `=false`). The hook gate is `=== "false"` → skip; the config DEFAULT is `"true"`.
- **Real-CLI test runs `--dangerously-skip-permissions` INSIDE Docker** (sandboxed) — the host classifier blocks it directly. Run via `bash test/functional/docker-run.sh handover` (needs Docker + `ANTHROPIC_API_KEY` or `DEEPSEEK_API_KEY`; billable; NOT in `pnpm test`).
- **Don't run git during a trunk-sync conflict.** The hook owns git. If a sync is blocked by an untracked/stale file, removing that file (a non-git `rm`) triggers a stage-all hook fire that completes the merge. Only fix file contents / clear blockers; never `git` directly.
- **Dual-harness:** the same `hooks/hooks.json` runs under Claude Code and Codex via `${CLAUDE_PLUGIN_ROOT}`. Any new hook (the Stop hook) must work on both.
- **The contree MENTAL_MODEL validator warnings** that fire in this repo are a known false-positive on the **root** monorepo index, not trunk-sync's — ignore them.

## Current verification (all green, option-A model)

- `pnpm test` → 190 node tests pass.
- `bash test/trunk-sync.test.sh` → 122 shell E2E pass.
- `bash test/functional/docker-run.sh handover` → 5 real-CLI checks pass.

## File map (timecard subsystem)

- Trees: `TEST_TREES.md` — `Domain: hook-plan` (`classifyTimecards`, `formatClockInMessage`, `formatSessionStartSummary`, `buildClockInPlan`), `Use-case: hook-execute` (`clockIn`, `clockOutStale`, `runSessionStart`, `runStop`, `executePlan with clock-in`), `Use-case: progress|clockin|clockout`, `System: hook-sync`.
- Types: `src/lib/hook-types.ts` (`Timecard`: sessionId, pid, hostname, clockedInAt, lastActiveAt=heartbeat, branch, task, lastStep, remainingSteps).
- Logic: `src/lib/hook-plan.ts` (pure), `src/lib/hook-execute.ts` (I/O + git).
- Entries: `src/lib/hook-entry.ts` (PostToolUse), `src/lib/session-start-entry.ts` (SessionStart); **to add:** `src/lib/stop-entry.ts`.
- Commands: `src/commands/progress.ts` (exists); **to add:** `clockin.ts`, `clockout.ts`.
- Hooks: `hooks/hooks.json`; wrappers `scripts/trunk-sync*.sh`.

## Immediate next step

Get the user's answers on **A** (clearing strategy) and **D** (staleness window), apply audit fixes **B/C/E/F/G/H** to the trees, then run the TDD plan above.
