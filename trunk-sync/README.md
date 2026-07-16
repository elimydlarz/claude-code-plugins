# trunk-sync

A distributed file system for multi-agent software engineering, built on Git.

Many Claude Code and Codex agents can work on the same branch at once from independent clones, including across remote machines. Their commits converge through the branch they share.

trunk-sync is a **Claude Code / Codex CLI hook** that turns Git into continuous integration for agents.

## Install

Install the plugin with your agent's plugin manager:

```bash
claude plugin marketplace add elimydlarz/claude-code-plugins
claude plugin install trunk-sync@elimydlarz
```

Or with Codex CLI:

```bash
codex plugin marketplace add elimydlarz/claude-code-plugins
codex plugin add trunk-sync@elimydlarz
```

Once the plugin is installed, repository changes made through the hooked agent tools are committed automatically and pushed when `origin` is configured.

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [Codex CLI](https://developers.openai.com/codex), and a Git repository with author name and email configured. An `origin` remote is optional; without one, trunk-sync commits locally.

## Configure

trunk-sync has no required configuration file. It acts on the repository containing the tool event, synchronizes the currently checked-out branch with the same-named branch at `origin`, and commits locally when `origin` is absent. Configure Git's `user.name`, `user.email`, credentials, and `origin` as you would for normal command-line use.

## How it works

After every `Edit`, `Write`, `Bash`, `apply_patch`, or `local_shell` use, the hook stages eligible repository changes and commits them. With `origin` configured, it then pulls and pushes the checked-out branch. Files outside the repository, ignored files, and tool uses that leave no changes are skipped.

Agents can still inspect Git with standalone commands such as `git status`, `git log`, `git show`, `git diff`, `git blame`, and read-only branch, tag, remote, worktree, stash, reflog, and config queries. Shell composition around Git, including `cd repo && git status`, is rejected; use a standalone form such as `git -C repo status`. Direct write-side Git commands are rejected so the hook remains the sync owner.

For multi-agent work, give each agent an independent clone checked out to the same branch:

```bash
git clone <repository> agent-a
git clone <repository> agent-b
cd agent-a && git checkout <branch> && claude
```

Across independent clones, if two agents edit the same file, trunk-sync surfaces the Git conflict as feedback. The agent resolves it by editing the file — then the hook completes the merge and pushes. No human intervention.

Every agent synchronizes the branch it has checked out. Agents in independent clones converge through the same-named remote branch.

### Checkout topology

Independent clones isolate in-progress files, the Git index, and merge state while converging through the same remote branch.

Linked worktrees remain branch-distinct checkouts. Git normally rejects checking out one branch in multiple linked worktrees; overriding that protection with `git worktree add --force` leaves separate indexes behind one moving branch ref. Use independent clones for same-branch collaboration.

Start each session from a clean index. Session start immediately creates a clock-in commit, and Git includes changes that were already staged in that commit.

Outside a Git repository, clock-in, synchronization, and clock-out exit without acting. The command guard still rejects write-side `git` commands in that session.

## Clocking In — agents that know about each other

Agents receive presence through the branch content they synchronize. On session start, the hook writes a presence-only timecard recording the agent's session, host, branch, clock-in time, and heartbeat. Timecards are committed locally and trunk-sync attempts to push them with that branch. On each later committed edit, the hook refreshes that card's `lastActiveAt` timestamp alongside the code change.

When another agent is working on the same branch:

```
TRUNK-SYNC ACTIVE: 1 other agent active. Continue your work as planned — no action required.
- abc12345 on dev-macbook (branch: main, 30s ago)
If you share resources (ports, test databases, build locks), coordinate accordingly. Otherwise, ignore this message.
```

An agent clocks in automatically on SessionStart and clocks out automatically when the Stop hook fires by removing its local timecard and attempting to sync that removal. If a session is disrupted before Stop runs, liveness falls back to the heartbeat age: within an hour it is active; after an hour it is stale and omitted from presence rosters; after 14 days it is reaped. There are no process IDs to check.

Failing tests — not the timecard — are the authoritative signal of unfinished work. Timecards are advisory presence context for coordinating around currently active sessions.

## Session Start — see active sessions

At session start the hook surfaces active committed timecards visible in the checkout:

```
TRUNK-SYNC ACTIVE: 1 other session is clocked in. Coordinate around shared resources when needed.
- 43605dd6 on dev-macbook (branch: main, 30s ago) — active: coordinate, do not duplicate
Timecards show presence only. Failing tests are the authoritative signal of unfinished work.
```

Because timecards are presence-only, stale cards are not treated as session summaries. A disrupted session's unfinished work is discovered through the test suite. Abandoned cards are reaped after 14 days.

## License

MIT
