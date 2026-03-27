# trunk-sync

Run multiple Claude Code agents on the same repo without breaking each other's work, and understand any line of generated code on demand.

## What it does

Every file edit is committed and pushed to `origin/main` automatically. Agents work in parallel — on local worktrees, across remote machines, any mix — with agentic conflict resolution. No more wasted time resolving conflicts by hand, remembering to commit, or discovering that an agent never pushed its work.

## Install

```bash
npm install -g trunk-sync
trunk-sync install
```

Project scope by default (active in the current repo, config committed to git). For user scope (all repos):

```bash
trunk-sync install --scope user
```

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI, `jq`, a git repo with a remote (`origin`).

## Scopes

| Scope | Config location | Effect |
|-------|----------------|--------|
| `project` (default) | `.claude/plugins.json` | Active in this repo only — committed to git so collaborators get it too |
| `user` | `~/.claude/plugins.json` | Active in all repos for this user |

## Usage

After every `Edit` or `Write`, trunk-sync commits, pulls, and pushes — automatically. It works on main, on branches, or in worktrees. No git commands, no manual merging.

For multi-agent work, launch each agent in its own worktree so they don't step on each other's working tree:

```bash
claude -w    # each invocation gets its own worktree
```

If two agents edit the same file, trunk-sync tells the agent to resolve the conflict by editing the file normally.

## Clocking In — who else is working

When multiple agents work in the same repo, each one clocks in by writing a timecard to `.trunk-sync/timeclock/`. Timecards are committed and pushed alongside code, so agents on different machines see each other too.

Each timecard records the agent's branch and current task (extracted from the conversation). When another agent is clocked in, the hook tells you:

```
TRUNK-SYNC CLOCK-IN: 1 other agent clocked in.
- abc12345 on dev-macbook (branch: main, 30s ago) — "Fix the login bug"
Consider potential resource conflicts: ports, build locks, test databases.
```

Agents with dead processes are automatically clocked out. Remote agents that haven't checked in for 5 minutes are clocked out too. The message is throttled to once every 5 minutes to avoid noise.

## Seance — talk to dead coding agents

Point at any line of code, and seance rewinds the codebase and the Claude session back to the exact moment that line was written. Ask the agent what it was thinking.

```bash
# Rewind and resume the session that wrote line 42
trunk-sync seance src/main.ts:42

# Just show which session wrote it, without launching Claude
trunk-sync seance src/main.ts:42 --inspect

# List all trunk-sync sessions in the repo
trunk-sync seance --list
```

Seance traces `git blame` back to the commit, rewinds the session transcript to that point, checks out the code at that commit, and resumes Claude with the same context it had when it wrote the line. The resumed agent is read-only — it explains and explores but cannot edit.

## Transcript commits

By default, seance finds session transcripts on the local filesystem (`~/.claude/projects/<slug>/<sessionId>.jsonl`). This works when tracing code written on the same machine, but the transcript won't exist if the code was written by an agent on a different machine, in CI, or if the local transcript has been cleaned up.

Enable transcript commits to solve this — each auto-commit will include a snapshot of the session transcript in `.transcripts/`:

```bash
trunk-sync config commit-transcripts true
```

With this enabled, seance can find the transcript directly in the commit via `git diff-tree`, regardless of which machine wrote the code. Recommended for teams and multi-machine workflows.

To disable:

```bash
trunk-sync config commit-transcripts false
```

**Security note:** Transcripts contain your full conversation with Claude, which may include sensitive context, proprietary code discussions, or credentials you pasted into the chat. With `commit-transcripts=true`, these are committed to git in the clear — anyone with repo access can read them. Only enable on repos where you're comfortable with transcript visibility, or where access is already restricted.

## License

MIT
