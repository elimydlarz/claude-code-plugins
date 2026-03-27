# CLAUDE.md

## Mental Model

This is the **susu-eng** monorepo — source code, plugin marketplace, and documentation for all Claude Code plugins and packages. The individual repos (`elimydlarz/trunk-sync`, `elimydlarz/req-mod-sync`, `elimydlarz/test-trees`, `elimydlarz/eli-rules`) are deprecated and point here.

Six products live in this repo:

- **trunk-sync** — multi-agent sync hook + seance CLI (Claude Code plugin + npm package `@susu-eng/trunk-sync`)
- **req-mod-sync** — auto-sync CLAUDE.md documentation (Claude Code plugin)
- **test-trees** — TDD enforcement + test framework setup (Claude Code plugin, pure Markdown skills)
- **contree** — test trees as living requirements: combines test-trees TDD + req-mod-sync sync into unified plugin (Claude Code plugin, pure Markdown skills + stop hook + coding rules)
- **openclaw-notifier** — notifies OpenClaw when a subagent completes a task (Claude Code plugin, SubagentStop hook)
- **eli-rules** — shared coding rules (npm package `@susu-eng/eli-rules`, not a marketplace plugin)

Users add this repo as a marketplace (`claude plugin marketplace add elimydlarz/claude-code-plugins`), then install individual plugins. The marketplace uses relative paths (`"source": "./trunk-sync"`) so plugins are installed directly from this repo. eli-rules is distributed via npm, not the plugin marketplace.

Note: trunk-sync's `install` command (`trunk-sync/src/commands/install.ts`) currently adds the old trunk-sync repo as the marketplace source — this needs updating to point to `elimydlarz/claude-code-plugins`.

## Repo Map

```
package.json                    — root package with publish scripts (pnpm publish:<project>)
.claude-plugin/marketplace.json — plugin catalog (name: susu-eng, relative paths to each plugin)
scripts/                        — publish scripts and shared helpers (bump-plugin-version.js)
README.md                       — unified docs for all products
CLAUDE.md                       — this file

trunk-sync/                     — multi-agent sync plugin + seance CLI (has its own CLAUDE.md)
req-mod-sync/                   — CLAUDE.md documentation sync plugin (has its own CLAUDE.md)
test-trees/                     — TDD enforcement plugin (has its own CLAUDE.md)
contree/                        — test trees as living requirements plugin (has its own CLAUDE.md)
eli-rules/                      — shared coding rules npm package (has its own CLAUDE.md)
```

Each subdirectory has its own `CLAUDE.md` with project-specific mental model, requirements, and development guidance.

## Publishing

All projects publish via pnpm scripts from the repo root:

```bash
pnpm publish:trunk-sync patch    # or minor, major
pnpm publish:eli-rules patch
pnpm publish:req-mod-sync patch
pnpm publish:test-trees patch
pnpm publish:contree patch
```

Each script checks for clean source, runs tests (if any), bumps the version, commits, tags, and pushes. trunk-sync and eli-rules also publish to npm. req-mod-sync and test-trees are marketplace-only — users get updates on `claude plugin marketplace update`.

## Updating the marketplace

To add or update a plugin listing, edit `.claude-plugin/marketplace.json` and push to GitHub. Users pick up changes on their next `claude plugin marketplace update`.

Each plugin entry needs `name` and `source` at minimum. For plugins in this repo, use relative paths:

```json
{
  "name": "plugin-name",
  "source": "./plugin-name"
}
```
