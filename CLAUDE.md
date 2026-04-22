# CLAUDE.md

## Mental Model

This is the **susu-eng** monorepo — source code, plugin marketplace, and documentation for all Claude Code plugins and packages. The individual repos (`elimydlarz/trunk-sync`, `elimydlarz/req-mod-sync`, `elimydlarz/test-trees`, `elimydlarz/eli-rules`) are deprecated and point here.

Four products live in this repo:

- **trunk-sync** — multi-agent sync hook + seance CLI (Claude Code plugin + npm package `@susu-eng/trunk-sync`)
- **contree** — test trees as living requirements: setup, change, sync, and TDD skills with stop hook + coding rules (Claude Code plugin, pure Markdown skills + stop hook)
- **openclaw-notifier** — notifies OpenClaw when a subagent completes a task (Claude Code plugin, SubagentStop hook)
- **climber** — build an autonomous clone that directs a Claude Code session the way you do (Claude Code plugin, Markdown skills + SessionStart & Stop hooks; `/climb` mines transcripts at build time, test-time skills consume artefacts, SessionStart hook injects the manual, Stop hook drives toward VISION.md; per-project opt-in via `.claude/settings.json` `enabledPlugins`)

Users add this repo as a marketplace (`claude plugin marketplace add elimydlarz/claude-code-plugins`), then install individual plugins. The marketplace uses relative paths (`"source": "./trunk-sync"`) so plugins are installed directly from this repo.

## Repo Map

```
package.json                    — root package with publish scripts (pnpm publish:<project>)
.claude-plugin/marketplace.json — plugin catalog (name: susu-eng, relative paths to each plugin)
scripts/                        — publish scripts and shared helpers (bump-plugin-version.js)
README.md                       — unified docs for all products
CLAUDE.md                       — this file

trunk-sync/                     — multi-agent sync plugin + seance CLI (has its own CLAUDE.md)
contree/                        — test trees as living requirements plugin (has its own CLAUDE.md)
openclaw-notifier/              — OpenClaw subagent completion notifier (has its own CLAUDE.md)
climber/                        — autonomous-clone builder plugin (has its own CLAUDE.md)
```

Each subdirectory has its own `CLAUDE.md` with project-specific mental model, requirements, and development guidance.

## Publishing

All projects publish via pnpm scripts from the repo root:

```bash
pnpm publish:trunk-sync patch    # or minor, major
pnpm publish:contree patch
pnpm publish:openclaw-notifier patch
pnpm publish:climber patch
```

Each script checks for clean source, runs tests (if any), bumps the version, commits, tags, and pushes. trunk-sync also publishes to npm.

## Updating the marketplace

To add or update a plugin listing, edit `.claude-plugin/marketplace.json` and push to GitHub. Users pick up changes on their next `claude plugin marketplace update`.

Each plugin entry needs `name` and `source` at minimum. For plugins in this repo, use relative paths:

```json
{
  "name": "plugin-name",
  "source": "./plugin-name"
}
```
