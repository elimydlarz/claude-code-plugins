# trunk-sync

A distributed file system for multi-agent software engineering, built on Git.

Many Claude Code agents can work in the same repo at once — on worktrees, across remote machines, on [OpenClaw](https://openclaw.com), any mix. Everything stays in sync, agents work around each other, nothing gets left behind, and there's nothing manual to do. If you're confused about some code an agent wrote, you can summon its author with Seance.

Two pieces: a **Claude Code / Codex CLI hook** that turns Git into continuous integration for agents, and a separate **CLI** with config, progress, and seance commands.

## Install

Install the plugin with your agent's plugin manager:

```bash
claude plugin install trunk-sync@elimydlarz
```

For Codex CLI, install `trunk-sync` from this repository through Codex's `/plugins` flow. The `trunk-sync` CLI is separate from plugin installation:

```bash
npm install -g @elimydlarz/trunk-sync
```

Once the plugin is installed, every file edit is committed and pushed automatically.

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [Codex CLI](https://developers.openai.com/codex), `jq`, a git repo with a remote (`origin`).

## How it works

After every `Edit` or `Write`, the hook fires: stage, commit, pull, push. Works on main, on branches, in worktrees. No git commands to remember, no manual merging, no work left behind on a branch nobody pushed.

For multi-agent work, launch each agent in its own worktree:

```bash
claude -w    # each invocation gets its own worktree
```

If two agents edit the same file, trunk-sync surfaces the conflict as feedback. The agent resolves it by editing the file — then the hook completes the merge and pushes. No human intervention.

By default, agents sync to a dedicated `agents` branch, not directly to your repo's actual default branch — see [Configuration](#configuration).

## Configuration

Config lives at `.trunk-sync/config` in the repo — committed and synced like timecards and transcripts, so every machine and agent working on the repo sees the same settings. It's not a personal dotfile: set a key once and it applies everywhere the repo is worked on.

```bash
trunk-sync config                        # show all config
trunk-sync config <key>                  # get a value
trunk-sync config <key>=<value>          # set a value
trunk-sync config --unset <key>          # remove a key
```

`trunk-sync config` with no arguments always prints every key below — explicit value if you've set it, built-in default otherwise — so it's the fastest way to see what's configurable without leaving the terminal:

```
$ trunk-sync config
commit-transcripts=true
target-branch=agents
```

Setting or unsetting a key commits the change immediately, and pushes it (best-effort) if a remote is configured — this is a manual command, not something that rides along with the next edit. Run outside a git repo, it runs `git init` first, so there's always a repo to store config in.

### Keys

- **`target-branch`** (default `agents`) — the branch trunk-sync syncs to. Agents commit and push here by default instead of your repo's actual default branch, so every edit's auto-commit doesn't land directly on `main` (or whatever it's called) — merging agent work in stays a deliberate step. Point it anywhere:
  ```bash
  trunk-sync config target-branch=main     # sync directly to main instead
  ```
- **`commit-transcripts`** (default `false`) — snapshot the session transcript into every commit. See [Transcript commits](#transcript-commits) below.

## Clocking In — agents that know about each other

Agents are automatically aware of each other. On every commit, the hook writes a timecard recording the agent's branch and current task (extracted from the conversation). Timecards are committed and pushed alongside code, so agents on different machines see each other too.

When another agent is working in the same repo:

```
TRUNK-SYNC ACTIVE: 1 other agent active. Continue your work as planned — no action required.
- abc12345 on dev-macbook (branch: main, 30s ago) — "Fix the login bug"
If you share resources (ports, test databases, build locks), coordinate accordingly. Otherwise, ignore this message.
```

An agent counts as active while its heartbeat is fresh — bumped on every edit, and at each turn's end by a Stop hook. After an hour of silence its card reads as stale (possibly disrupted); abandoned cards are reaped only after 14 days. There are no process IDs to check and no clock-out command — liveness is purely the age of the last heartbeat. The message is throttled to avoid noise.

On its **first** edit of a session, an agent is also nudged to run the test suite:

```
TRUNK-SYNC WIP: Run the test suite before starting. Failing tests are the authoritative signal of
unfinished work — any failing test not owned by a currently-active agent is WIP for you to resume.
The active roster above is advisory context for who already holds work.
```

Failing tests — not the timecard — are the authoritative signal of unfinished work. Cross-referencing them against who is still active tells a fresh agent which unfinished work is orphaned and safe to pick up; the cards are advisory context.

## Handover — continue across sessions and context limits

When a session is running low on context, it can hand off to the next one. At session start the hook gives the agent its own session id and shows it how to record progress:

```bash
trunk-sync progress <session-id> --last "implemented the parser" --next "wire the CLI and write tests"
```

That last step and remaining steps are written into the agent's timecard and committed/pushed like any other. When the next session starts — yours after a fresh start, or another agent's, on any machine — its SessionStart surfaces the handover:

```
TRUNK-SYNC HANDOVER: 1 other session has work in progress. Failing tests on the trunk are the
authoritative signal of what is unfinished; the cards below are advisory context.
- 43605dd6 on dev-macbook (branch: main, 3h ago) — stale, possibly disrupted: verify against the test suite before resuming — it may already be done
    task: Add agent-authored progress to trunk-sync
    last: implemented the parser
    next: wire the CLI and write tests
Each session's full record is in its committed transcript (.transcripts/); resume it with seance.
```

So you can stop a session that's low on context — or one that crashes mid-task — and pick the work up in a fresh one without re-explaining where you were. Because liveness is a heartbeat rather than a live process, a disrupted session's work is surfaced as a resumable handover instead of being lost; abandoned cards are reaped only after 14 days, and the committed transcript remains the durable record regardless.

## Seance — summon the author of any line of code

Point at any line, and seance rewinds the codebase and the agent's session back to the exact moment that line was written. Ask the agent what it was thinking, why it made that choice, what it considered and rejected. Works for both Claude and Codex commits — seance reads the commit body's `Agent:` field and forks the matching CLI.

```bash
# Rewind and resume the session that wrote line 42
trunk-sync seance src/main.ts:42

# Just show which session wrote it, without launching the CLI
trunk-sync seance src/main.ts:42 --inspect

# List all trunk-sync sessions in the repo
trunk-sync seance --list
```

Under the hood: `git blame` → commit → session ID + agent → transcript rewind → checkout at that commit → resume the original CLI with the same context it had. Read-only: Claude is launched with `--allowedTools Read` + plan mode; Codex is launched with `--sandbox read-only --ask-for-approval never`. The resumed agent explains and explores but cannot edit.

### Transcript commits

By default, session transcripts are **not** committed to git. To enable them — so seance can find them directly in the commit via `git diff-tree` regardless of which machine wrote the code, across machines and CI:

```bash
trunk-sync config commit-transcripts=true
```

Transcripts contain your full conversation with Claude, committed to git in the clear. If you prefer that visibility only on certain repos, enable it there explicitly; for most projects, leaving the default off is fine.

## License

MIT
