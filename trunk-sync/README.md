# trunk-sync

A distributed file system for multi-agent software engineering, built on Git.

Many Claude Code agents can work in the same repo at once — on worktrees, across remote machines, on [OpenClaw](https://openclaw.com), any mix. Everything stays in sync, agents work around each other, and nothing gets left behind.

trunk-sync is a **Claude Code / Codex CLI hook** that turns Git into continuous integration for agents.

## Install

Install the plugin with your agent's plugin manager:

```bash
claude plugin install trunk-sync@elimydlarz
```

For Codex CLI, install `trunk-sync` from this repository through Codex's `/plugins` flow.

Once the plugin is installed, every file edit is committed and pushed automatically.

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [Codex CLI](https://developers.openai.com/codex), a git repo with a remote (`origin`).

## How it works

After every `Edit` or `Write`, the hook fires: stage, commit, pull, push. Works on branches and in worktrees. No git commands to remember, no manual merging, no work left behind on a branch nobody pushed.

For multi-agent work, launch each agent in its own worktree:

```bash
claude -w    # each invocation gets its own worktree
```

If two agents edit the same file, trunk-sync surfaces the conflict as feedback. The agent resolves it by editing the file — then the hook completes the merge and pushes. No human intervention.

Agents sync to a dedicated `agents` branch, not directly to your repo's actual default branch, so merging agent work into `main` stays a deliberate step.

## Clocking In — agents that know about each other

Agents are automatically aware of each other. On session start, the hook writes a presence-only timecard recording the agent's session, host, branch, clock-in time, and heartbeat. Timecards are committed and pushed, so agents on different machines see each other too. On each later committed edit, the hook refreshes that card's `lastActiveAt` timestamp alongside the code change.

When another agent is working in the same repo:

```
TRUNK-SYNC ACTIVE: 1 other agent active. Continue your work as planned — no action required.
- abc12345 on dev-macbook (branch: main, 30s ago)
If you share resources (ports, test databases, build locks), coordinate accordingly. Otherwise, ignore this message.
```

An agent clocks in automatically on SessionStart and clocks out automatically when the Stop hook fires by removing and syncing its timecard. If a session is disrupted before Stop runs, liveness falls back to the heartbeat age: within an hour it is active; after an hour it is stale and omitted from presence rosters; after 14 days it is reaped. There are no process IDs to check.

Failing tests — not the timecard — are the authoritative signal of unfinished work. Timecards are advisory presence context for coordinating around currently active sessions.

## Session Start — see active sessions

At session start the hook gives the agent its own session id and surfaces other active committed timecards:

```
TRUNK-SYNC ACTIVE: 1 other session is clocked in. Coordinate around shared resources when needed.
- 43605dd6 on dev-macbook (branch: main, 30s ago) — active: coordinate, do not duplicate
Timecards show presence only. Failing tests are the authoritative signal of unfinished work.
```

Because timecards are presence-only, stale cards are not treated as session summaries. A disrupted session's unfinished work is discovered through the test suite. Abandoned cards are reaped after 14 days.

## License

MIT
