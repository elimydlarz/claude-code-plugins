# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mental Model

The mental model lives in [MENTAL_MODEL.md](./MENTAL_MODEL.md) — Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, and Temporal View. It covers the hook, configurable target branch (`agents` by default), and the timeclock.

## Repo Map

```
.claude-plugin/plugin.json    — plugin manifest (name, version)
.claude-plugin/marketplace.json — marketplace definition (name: elimydlarz, lists plugins)
dist/                         — compiled JS (tracked in git — marketplace installs from repo)
hooks/hooks.json              — hook registration (PostToolUse Edit|Write|Bash → trunk-sync.sh; SessionStart → trunk-sync-session-start.sh; Stop → trunk-sync-stop.sh)
scripts/trunk-sync.sh         — 4-line bash wrapper: exec node dist/lib/hook-entry.js
scripts/trunk-sync-session-start.sh — SessionStart wrapper: exec node dist/lib/session-start-entry.js
scripts/trunk-sync-stop.sh    — Stop wrapper: exec node dist/lib/stop-entry.js
scripts/bump-plugin-manifests.js — release helper: bumps both plugin manifests from their shared version

src/lib/hook-types.ts         — types (HookInput, RepoState, HookPlan, Timecard: session, host, clockedInAt, lastActiveAt, branch, no pid)
src/lib/hook-plan.ts          — pure decision logic (no I/O, no git); incl. classifyTimecards (heartbeat-age), formatSessionStartSummary
src/lib/hook-plan.domain.test.ts — domain tests for pure logic (fast, no repos)
src/lib/command-guard.ts      — pure policy for allowed and rejected agent git commands
src/lib/command-guard.domain.test.ts — domain tests for command policy
src/lib/hook-execute.ts       — gathers git state, executes the plan; incl. runSessionStart, runStop (clock-out), reapCards
src/lib/hook-execute.adapter.test.ts — adapter tests against real temp git repos
src/lib/pre-tool-entry.ts     — PreToolUse command-guard adapter
src/lib/pre-tool-entry.adapter.test.ts — command-guard protocol tests
src/lib/hook-entry.ts         — PostToolUse entry point: reads stdin, wires layers, exits
src/lib/session-start-entry.ts — SessionStart entry point: creates/syncs own timecard and prints active peers to stdout
src/lib/stop-entry.ts         — Stop entry point: removes the session timecard + syncs; never forces

test/system/hook-sync.system.test.mjs — hook System contract over real shell scenarios with temp repos and a bare remote
test/journey/                 — Dockerized real-agent Journey for Claude Code and Codex
test/local-setup.sh           — manual test setup
test/local-cleanup.sh         — manual test teardown
```

## Behaviour Contract

Behavioural requirements live as test trees in [`TEST_TREES.md`](./TEST_TREES.md). Each tree reifies one test file; each path corresponds to one `describe`/`it`. Trees are the contract — modify trees before code, then drive code from failing tests.

## Conventions (non-behavioural)

- **version-sync**: the release helper bumps both plugin manifests together from their shared version
- **dist-tracked**: `dist/` is committed to git (excluding tests and `.d.ts`) so marketplace plugin installs have the compiled hook entry point
- **doc-alignment**: user-facing docs and rules must stay consistent with the trees — worktree mode is optional (for multi-agent), not required for single-agent use

## Development

### Tests

```bash
# TypeScript tests (node:test)
pnpm run build && pnpm test

# Hook e2e tests (shell, TAP output)
pnpm run test:e2e

# Real Claude Code and Codex functional journey (Docker + DEEPSEEK_API_KEY)
pnpm run test:functional
```

Hook tests create isolated temp repos with worktrees and a bare remote. Safe to run anywhere — no network access needed.

### Building

```bash
pnpm run build        # compile TypeScript → dist/
```

### Manual testing

Scripts for testing the hook live against origin with real worktrees. The hook targets `agents` by default; repositories can override it with `.trunk-sync/config`'s `target-branch`.

```bash
# 1. Setup
bash test/local-setup.sh

# 2. Launch two agents in worktrees
#    Terminal 1:
claude -w
#    Terminal 2:
claude -w

# 3. Give each agent a task that edits test/battlefield.txt
#    They will conflict on the same file and the hook will handle it.

# 4. Verify
git log --oneline origin/agents # should have auto-commits + local-only commit
git status
cat test/battlefield.txt         # should reflect the resolved content

# 5. Cleanup
bash test/local-cleanup.sh
```

### Publishing

Publish from the repository root through the release script:

```bash
pnpm publish:trunk-sync patch --notes-file /tmp/trunk-sync-notes.md
```

Choose `patch`, `minor`, or `major`. The notes file is required; omitting it prints the exact command for reviewing changes since the previous Trunk Sync tag. The script requires clean source, bumps both plugin manifests together, commits and tags the release, pushes to GitHub, and creates the GitHub release. Building and testing remain the maintainer's responsibility before release.

GitHub is the distribution source: the marketplace installs directly from this repository. `dist/` is tracked because consumers have no build step. Test files and `.d.ts` are gitignored.


### Key conventions

- Hook no longer requires `jq` at runtime (TypeScript handles JSON parsing)
- All TypeScript imports use `.js` extensions (Node16 ESM requirement)
- Hook exit codes: 0 = success/no-op, 2 = conflict/failure with agent feedback on stderr

### Testing conventions

- Every exported function must have tests — when adding a new export, add tests in the same PR
- Three-layer rule: pure logic → unit tests; git/fs callers → integration tests (real temp repos); shell E2E as safety net
- Test file placement: `foo.ts` → `foo.test.ts`
- Reuse helpers: `initRepo()`, `makeInput()`, `makeState()`, `setupRepoWithRemote()`
- No mocks for git — use real temp repos with `mkdtempSync`
- Execution functions (`executePlan`, `executeSync`) require tests covering changed behavior
