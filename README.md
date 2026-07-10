# elimydlarz — Claude Code Plugins

Tools for working with Claude Code: parallel agent coordination, test-driven development, living documentation, and shared coding rules.

## Setup

Add the plugin marketplace:

```sh
claude plugin marketplace add elimydlarz/claude-code-plugins
```

Then install what you need:

| Tool | Install | What it does |
|------|---------|--------------|
| [trunk-sync](trunk-sync/README.md) | Plugin: `claude plugin install trunk-sync@elimydlarz` (Claude Code) — Codex CLI: install from this repo via `/plugins` | Auto-commit every edit to trunk — run multiple agents in parallel |
| [contree](contree/README.md) | `claude plugin install contree@elimydlarz` (Claude Code) — Codex CLI: install from this repo via `/plugins` | Test trees as living requirements — TDD with auto-synced specs in TEST_TREES.md |

Integration surface notes live in [CLAUDE_CODE_INTERFACE.md](CLAUDE_CODE_INTERFACE.md) and [CODEX_INTERFACE.md](CODEX_INTERFACE.md).

---

## Publishing (maintainers)

### trunk-sync

```bash
git log v3.8.3..HEAD -- trunk-sync/ ':!trunk-sync/dist/'   # review and draft notes
./scripts/publish-trunk-sync.sh patch --notes-file notes.md   # or minor, major
```

Builds, tests (unit + e2e), bumps version, pushes to GitHub, and cuts a GitHub release from the supplied notes file. The `--notes-file` is required; running without it prints the exact `git log` command for the previous tag.

## License

MIT
