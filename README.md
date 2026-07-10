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

Releases are published from the repository root. Review the product's changes since its latest tag, write release notes, and choose `patch`, `minor`, or `major`:

```bash
pnpm publish:contree patch --notes-file /tmp/contree-notes.md
pnpm publish:trunk-sync patch --notes-file /tmp/trunk-sync-notes.md
```

The notes file is required. Running either command without it fails and prints the exact `git log` command for reviewing changes since that product's previous tag.

Both commands require a semantic version change kind, bump the Claude Code and Codex plugin manifests, commit and tag the release, push `main` and the tag to GitHub, and create a GitHub release. They do not build or run tests; the maintainer does that separately before release. Contree refreshes its Claude Code marketplace installation after publishing.

## License

MIT
