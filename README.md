# susu-eng — Claude Code Plugins

Tools for working with Claude Code: parallel agent coordination, test-driven development, living documentation, and shared coding rules.

## Setup

Add the plugin marketplace:

```sh
claude plugin marketplace add elimydlarz/claude-code-plugins
```

Then install what you need:

| Tool | Install | What it does |
|------|---------|--------------|
| trunk-sync | `npm i -g trunk-sync && trunk-sync install` | Auto-commit every edit to trunk — run multiple agents in parallel |
| req-mod-sync | `claude plugin install req-mod-sync@susu-eng` | Keep CLAUDE.md requirements and mental model in sync with code |
| test-trees | `claude plugin install test-trees@susu-eng` | Enforce TDD with human-readable test tree output |
| eli-rules | `pnpm add -D @susu-eng/eli-rules` | Shared coding rules synced to `.claude/rules/` |

The marketplace is needed for trunk-sync, req-mod-sync, and test-trees. eli-rules is an npm package — install it directly.

### Migrating from individual repos

If you previously added a marketplace from one of the individual repos (`elimydlarz/trunk-sync`, `elimydlarz/req-mod-sync`, or `elimydlarz/test-trees`), remove it and switch to this one:

```sh
# Remove old marketplace sources
claude plugin marketplace remove trunk-sync
claude plugin marketplace remove req-mod-sync
claude plugin marketplace remove test-trees

# Uninstall plugins installed from old sources
claude plugin uninstall trunk-sync@susu-eng
claude plugin uninstall req-mod-sync@susu-eng
claude plugin uninstall test-trees@test-trees

# Add the unified marketplace and reinstall
claude plugin marketplace add elimydlarz/claude-code-plugins
claude plugin install trunk-sync@susu-eng
claude plugin install req-mod-sync@susu-eng
claude plugin install test-trees@susu-eng
```

---

## trunk-sync

Run multiple Claude Code agents on the same repo without breaking each other's work, and understand any line of generated code on demand.

### What it does

Every file edit is committed and pushed to `origin/main` automatically. Agents work in parallel — on local worktrees, across remote machines, any mix — with agentic conflict resolution. No more wasted time resolving conflicts by hand, remembering to commit, or discovering that an agent never pushed its work.

### Install

```bash
npm install -g trunk-sync
trunk-sync install
```

Project scope by default (active in the current repo, config committed to git). For user scope (all repos):

```bash
trunk-sync install --scope user
```

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI, `jq`, a git repo with a remote (`origin`).

### Scopes

| Scope | Config location | Effect |
|-------|----------------|--------|
| `project` (default) | `.claude/plugins.json` | Active in this repo only — committed to git so collaborators get it too |
| `user` | `~/.claude/plugins.json` | Active in all repos for this user |

### Usage

After every `Edit` or `Write`, trunk-sync commits, pulls, and pushes — automatically. It works on main, on branches, or in worktrees. No git commands, no manual merging.

For multi-agent work, launch each agent in its own worktree so they don't step on each other's working tree:

```bash
claude -w    # each invocation gets its own worktree
```

If two agents edit the same file, trunk-sync tells the agent to resolve the conflict by editing the file normally.

### Seance — talk to dead coding agents

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

### Transcript commits

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

---

## req-mod-sync

Claude Code plugin that keeps your project documentation accurate. Requirements, mental models, and repo maps are the context Claude works from on every task. When they drift, Claude makes decisions based on stale assumptions. This plugin catches that drift automatically.

### What it does

After every response, Claude is prompted to check whether `CLAUDE.md` needs updating:

1. `## Requirements` — functional and cross-functional requirements
2. `## Mental Model` — key concepts, architecture, relationships, lifecycle
3. `## Repo Map` — key files and directories — what lives where
4. Rest of `CLAUDE.md` — procedures, rules, conventions

If nothing needs updating, it continues without changes.

### Install

```sh
claude plugin install req-mod-sync@susu-eng --scope project
```

This adds `"req-mod-sync@susu-eng": true` to `.claude/settings.json`. Commit that file to share with your team. Restart Claude Code after installing.

### Uninstall

```sh
claude plugin uninstall req-mod-sync@susu-eng
```

---

## test-trees

Claude Code plugin that enforces test-driven development with human-readable test tree output. Tests are contracts and documentation — they describe operating principles, not just enumerate cases.

### Skills

**`/setup-test-trees`** — Run once per project to configure your test framework:

1. Detects your language and test framework (or recommends one)
2. Configures a tree-style reporter so test output reads as a specification
3. Sets up a changed-test runner for fast TDD feedback
4. Updates your project's `CLAUDE.md` with concrete test commands

Supports Vitest, Jest, Mocha, pytest, RSpec, Go, PHPUnit, JUnit 5, Bats, Rust, Elixir, C#/.NET, Swift.

**`tdd`** — Auto-triggers when Claude detects changes to behavior, interfaces, or tests. Enforces the red/green/refactor cycle:

- Write one failing test first, then make it pass, then refactor
- Tests describe what software does via nested describe/context blocks
- London-school TDD: start from outermost surface, work inward
- Colocate tests with source (`*.unit.test.*` or `*.int.test.*`)

Example test tree output:

```
searchMemoryTool
  parameters schema
    when <= 3 queries provided
      then accepts
    when > 3 queries provided
      then rejects
```

### Install

```sh
claude plugin install test-trees@susu-eng --scope project
```

### Uninstall

```sh
claude plugin uninstall test-trees@susu-eng
```

---

## eli-rules

Reusable Claude Code rules for coding principles and practices. Install as a dev dependency and rules sync to `.claude/rules/` automatically.

### Install

```sh
pnpm add -D @susu-eng/eli-rules
```

Rules are copied on `postinstall` — no extra setup. Each rule is namespaced (`susu-eng--eli-rules--kiss.md`) so it's safe alongside your own rules.

### Manual sync

```sh
pnpm exec eli-rules-sync
```

### Included rules

| Rule | Description |
|------|-------------|
| KISS | Simplicity above almost all else |
| YAGNI | Don't future-proof — you won't need it |
| Subtract, don't add | Solve by subtraction first |
| Avoid indirection | Simplicity over arbitrary patterns |
| Avoid nullability | Required over nullable |
| Composition | Composition over inheritance |
| Consumer-driven | Outside-in, implement what's needed |
| Explicit and expressive | Name things for what they do |
| Fail fast | Let the system fail loudly |
| Integration testing | Mock external deps only |
| No fake code | No skeleton/placeholder code |
| No swallowed errors | Never hide errors |
| Read docs | Use Context7 MCP, never guess APIs |
| Self-documenting | Clear code over comments |
| Typing | Type everything, no `any` |
| Verification | Always run verification commands |
| Z-index | Avoid z-index when possible |
| pnpm | Always use pnpm for JS/TS |

---

## Publishing (maintainers)

### trunk-sync

```bash
./scripts/publish-trunk-sync.sh patch   # or minor, major
```

Single command: builds, tests (unit + e2e), bumps version, publishes to npm, pushes to GitHub. Both distribution channels (npm package + marketplace plugin) updated together.

### eli-rules

From the `eli-rules` directory:

```bash
pnpm version patch
pnpm publish
git push origin main --follow-tags
```

### req-mod-sync / test-trees

No build or publish step — installed directly from GitHub via the marketplace. Push to the repo and users get updates on `claude plugin marketplace update`.

## License

MIT
