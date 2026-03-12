# CLAUDE.md

## Mental Model

This is the **susu-eng** monorepo — source code, plugin marketplace, and documentation for all Claude Code plugins and packages. The individual repos (`elimydlarz/trunk-sync`, `elimydlarz/req-mod-sync`, `elimydlarz/test-trees`, `elimydlarz/eli-rules`) are deprecated and point here.

Four products live in this repo:

- **trunk-sync** — multi-agent sync hook + seance CLI (Claude Code plugin + npm package `@susu-eng/trunk-sync`)
- **req-mod-sync** — auto-sync CLAUDE.md documentation (Claude Code plugin)
- **test-trees** — TDD enforcement + test framework setup (Claude Code plugin, pure Markdown skills)
- **eli-rules** — shared coding rules (npm package `@susu-eng/eli-rules`, not a marketplace plugin)

Users add this repo as a marketplace (`claude plugin marketplace add elimydlarz/claude-code-plugins`), then install individual plugins. The marketplace uses relative paths (`"source": "./trunk-sync"`) so plugins are installed directly from this repo. eli-rules is distributed via npm, not the plugin marketplace.

Note: trunk-sync's `install` command (`trunk-sync/src/commands/install.ts`) currently adds the old trunk-sync repo as the marketplace source — this needs updating to point to `elimydlarz/claude-code-plugins`.

## Repo Map

```
.claude-plugin/marketplace.json — plugin catalog (name: susu-eng, relative paths to each plugin)
scripts/publish-trunk-sync.sh   — full publish workflow: build, test, version, npm publish, git push
README.md                       — unified docs for all products
CLAUDE.md                       — this file

trunk-sync/                     — multi-agent sync plugin + seance CLI (has its own CLAUDE.md)
req-mod-sync/                   — CLAUDE.md documentation sync plugin (has its own CLAUDE.md)
test-trees/                     — TDD enforcement plugin (has its own CLAUDE.md)
eli-rules/                      — shared coding rules npm package (has its own CLAUDE.md)
```

Each subdirectory has its own `CLAUDE.md` with project-specific mental model, requirements, and development guidance.

## Publishing

### trunk-sync

```bash
./scripts/publish-trunk-sync.sh patch   # or minor, major
```

The script operates on `trunk-sync/` and:
1. Checks for clean source (dist/ staleness is handled automatically)
2. Builds and runs all tests (unit + e2e)
3. Commits dist/ if stale
4. Bumps version via `pnpm version` (lifecycle script syncs plugin.json)
5. Publishes to npm (`@susu-eng/trunk-sync`)
6. Pushes to GitHub with tags

Both distribution channels (npm + marketplace) are updated in one command.

### eli-rules

From `eli-rules/`:

```bash
pnpm version patch
pnpm publish
```

Then push this repo to update the marketplace.

### req-mod-sync / test-trees

No build or publish step — installed directly from this repo via the marketplace. Push this repo and users get updates on `claude plugin marketplace update`.

## Updating the marketplace

To add or update a plugin listing, edit `.claude-plugin/marketplace.json` and push to GitHub. Users pick up changes on their next `claude plugin marketplace update`.

Each plugin entry needs `name` and `source` at minimum. For plugins in this repo, use relative paths:

```json
{
  "name": "plugin-name",
  "source": "./plugin-name"
}
```
