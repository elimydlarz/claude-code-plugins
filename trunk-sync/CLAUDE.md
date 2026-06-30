# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Mental Model

The mental model lives in [MENTAL_MODEL.md](./MENTAL_MODEL.md) — Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, and Temporal View. It covers the hook/CLI split, seance, the timeclock, and the non-obvious Codex-resume fact (rollouts are found by path, not DB insertion).

## Repo Map

```
.claude-plugin/plugin.json    — plugin manifest (name, version)
.claude-plugin/marketplace.json — marketplace definition (name: elimydlarz, lists plugins)
dist/                         — compiled JS (tracked in git — marketplace installs from repo)
hooks/hooks.json              — hook registration (PostToolUse Edit|Write|Bash → trunk-sync.sh; SessionStart → trunk-sync-session-start.sh)
scripts/trunk-sync.sh         — 4-line bash wrapper: exec node dist/lib/hook-entry.js
scripts/trunk-sync-session-start.sh — SessionStart wrapper: exec node dist/lib/session-start-entry.js
scripts/sync-plugin-version.js — npm version hook: syncs plugin.json version from package.json

src/lib/hook-types.ts         — types (HookInput, RepoState, HookPlan, Timecard incl. lastStep/remainingSteps)
src/lib/hook-plan.ts          — pure decision logic (no I/O, no git); incl. formatSessionStartSummary
src/lib/hook-plan.test.ts     — unit tests for pure logic (fast, no repos)
src/lib/hook-execute.ts       — gathers git state, executes the plan; incl. runSessionStart
src/lib/hook-execute.test.ts  — integration tests (temp repos)
src/lib/hook-entry.ts         — PostToolUse entry point: reads stdin, wires layers, exits
src/lib/session-start-entry.ts — SessionStart entry point: prints own-id + handover roster to stdout

src/cli.ts                    — CLI entry point, argv dispatch
src/commands/install.ts       — trunk-sync install
src/commands/seance.ts        — trunk-sync seance (default/--inspect/--list modes)
src/commands/config.ts        — trunk-sync config (read/write ~/.trunk-sync; commit-transcripts defaults on)
src/commands/progress.ts      — trunk-sync progress (agent records lastStep/remainingSteps into its timecard)
src/commands/progress.test.ts — progress command tests (node:test)
src/commands/config.test.ts   — config command tests (node:test)
src/commands/install.test.ts  — install command tests (node:test)
.transcripts/                 — session snapshots committed by hook (on by default; opt out via commit-transcripts=false)
src/lib/git.ts                — shared git utilities (blame, parseFileRef, extractSessionId, findSnapshotInCommit)
src/lib/git.test.ts           — unit tests (node:test)
src/commands/seance.test.ts   — integration tests (node:test)

test/trunk-sync.test.sh       — hook e2e test suite (TAP, temp repos + bare remote); System-layer, simulates hook stdin
test/functional/              — real-CLI System test (Docker): drives actual claude, handover case, deterministic self-verify (manual, billable)
test/local-setup.sh           — manual test setup
test/local-cleanup.sh         — manual test teardown
```

## Behaviour Contract

Behavioural requirements live as test trees in [`TEST_TREES.md`](./TEST_TREES.md). Each tree reifies one test file; each path corresponds to one `describe`/`it`. Trees are the contract — modify trees before code, then drive code from failing tests.

## Conventions (non-behavioural)

- **version-sync**: `npm version` automatically updates `.claude-plugin/plugin.json` to match `package.json` via the `version` lifecycle script
- **dist-tracked**: `dist/` is committed to git (excluding tests and `.d.ts`) so marketplace plugin installs have the compiled hook entry point
- **doc-alignment**: user-facing docs (README, rules, CLI output) must stay consistent with the trees — worktree mode is optional (for multi-agent), not required for single-agent use

## Development

### Tests

```bash
# CLI tests (TypeScript, node:test)
pnpm run build && pnpm test

# Hook e2e tests (shell, TAP output)
pnpm run test:e2e
```

Hook tests create isolated temp repos with worktrees and a bare remote. Safe to run anywhere — no network access needed.

### Building the CLI

```bash
pnpm run build        # compile TypeScript → dist/
pnpm run dev -- <cmd> # run from source via tsx
```

### Manual testing

Scripts for testing the hook live against origin with real worktrees:

```bash
# 1. Setup — commits a file on local main without pushing
bash test/local-setup.sh

# 2. Launch two agents in worktrees
#    Terminal 1:
claude -w
#    Terminal 2:
claude -w

# 3. Give each agent a task that edits test/battlefield.txt
#    They will conflict on the same file and the hook will handle it.

# 4. Verify
git log --oneline origin/main   # should have auto-commits + local-only commit
git status                       # main should be clean and up to date
cat test/battlefield.txt         # should reflect the resolved content

# 5. Cleanup — resets local main and origin/main to pre-test state,
#    removes all worktrees and trunk-sync branches
bash test/local-cleanup.sh
```

### Publishing

Two distribution channels — both must be updated together:

```bash
# 1. Bump version in both manifests
#    - package.json (npm)
#    - .claude-plugin/plugin.json (plugin)

# 2. Build (dist/ is tracked — marketplace installs need compiled JS)
pnpm run build

# 3. Publish to npm (prepublishOnly also runs build)
pnpm publish

# 4. Push to GitHub (plugin installs from repo root)
git push origin main
```

`dist/` is tracked in git because the marketplace plugin installs directly from the repo — without compiled JS, the hook silently fails. Test files and `.d.ts` are gitignored. The npm tarball uses the `files` field in `package.json` to select what ships.


### Key conventions

- Hook no longer requires `jq` at runtime (TypeScript handles JSON parsing); `jq` is still checked by `install` command
- CLI has zero runtime dependencies — only devDependencies (typescript, tsx, @types/node)
- All TypeScript imports use `.js` extensions (Node16 ESM requirement)
- Hook exit codes: 0 = success/no-op, 2 = conflict/failure with agent feedback on stderr

### Testing conventions

- Every exported function must have tests — when adding a new export, add tests in the same PR
- Three-layer rule: pure logic → unit tests; git/fs callers → integration tests (real temp repos); shell E2E as safety net
- Test file placement: `foo.ts` → `foo.test.ts`, CLI tests in `src/commands/`
- Reuse helpers: `initRepo()`, `makeInput()`, `makeState()`, `setupRepoWithRemote()`
- No mocks for git — use real temp repos with `mkdtempSync`
- CLI command tests via subprocess (`node dist/cli.js`)
- Execution functions (`executePlan`, `executeSync`, `amendWithTranscriptSnapshot`) require tests covering changed behavior
