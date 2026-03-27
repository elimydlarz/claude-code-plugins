# trunk-sync

A distributed file system for multi-agent software engineering, built on Git.

Many Claude Code agents can work in the same repo at once — on worktrees, across remote machines, on [OpenClaw](https://openclaw.com), any mix. Everything stays in sync, agents work around each other, nothing gets left behind, and there's nothing manual to do. If you're confused about some code an agent wrote, you can summon its author with Seance.

Two pieces: a **Claude Code hook** that turns Git into continuous integration for agents, and a **CLI** with install, config, and seance commands.

## Install

```bash
npm install -g trunk-sync
trunk-sync install
```

That's it. Every file edit is now committed and pushed automatically.

Project scope by default (config committed to git, so collaborators get it too). For user scope (all repos):

```bash
trunk-sync install --scope user
```

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI, `jq`, a git repo with a remote (`origin`).

## How it works

After every `Edit` or `Write`, the hook fires: stage, commit, pull, push. Works on main, on branches, in worktrees. No git commands to remember, no manual merging, no work left behind on a branch nobody pushed.

For multi-agent work, launch each agent in its own worktree:

```bash
claude -w    # each invocation gets its own worktree
```

If two agents edit the same file, trunk-sync surfaces the conflict as feedback. The agent resolves it by editing the file — then the hook completes the merge and pushes. No human intervention.

## Clocking In — agents that know about each other

Agents are automatically aware of each other. On every commit, the hook writes a timecard recording the agent's branch and current task (extracted from the conversation). Timecards are committed and pushed alongside code, so agents on different machines see each other too.

When another agent is working in the same repo:

```
TRUNK-SYNC CLOCK-IN: 1 other agent clocked in.
- abc12345 on dev-macbook (branch: main, 30s ago) — "Fix the login bug"
Consider potential resource conflicts: ports, build locks, test databases.
```

Agents with dead processes are automatically clocked out. Remote agents that go silent are clocked out after 5 minutes. The message is throttled to avoid noise.

## Seance — summon the author of any line of code

Point at any line, and seance rewinds the codebase and the Claude session back to the exact moment that line was written. Ask the agent what it was thinking, why it made that choice, what it considered and rejected.

```bash
# Rewind and resume the session that wrote line 42
trunk-sync seance src/main.ts:42

# Just show which session wrote it, without launching Claude
trunk-sync seance src/main.ts:42 --inspect

# List all trunk-sync sessions in the repo
trunk-sync seance --list
```

Under the hood: `git blame` → commit → session ID → transcript rewind → checkout at that commit → resume Claude with the same context it had. The resumed agent is read-only — it explains and explores but cannot edit.

### Transcript commits

By default, seance finds transcripts on the local filesystem. This works for code written on the same machine, but not for code from other machines, CI, or cleaned-up sessions.

Enable transcript commits to fix this:

```bash
trunk-sync config commit-transcripts true
```

Each auto-commit will include a snapshot of the session transcript. Seance can then find the transcript directly in the commit via `git diff-tree`, regardless of which machine wrote the code. Recommended for teams and multi-machine workflows.

**Security note:** Transcripts contain your full conversation with Claude. With `commit-transcripts=true`, these are committed to git in the clear. Only enable on repos where you're comfortable with that visibility.

## License

MIT
