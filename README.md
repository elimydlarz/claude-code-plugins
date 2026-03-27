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
| [trunk-sync](trunk-sync/README.md) | `npm i -g trunk-sync && trunk-sync install` | Auto-commit every edit to trunk — run multiple agents in parallel |
| [contree](contree/README.md) | `claude plugin install contree@susu-eng` | Test trees as living requirements — TDD with auto-synced specs in CLAUDE.md |
| openclaw-notifier | `claude plugin install openclaw-notifier@susu-eng` | Notify OpenClaw when a subagent completes a task |

---

## Publishing (maintainers)

### trunk-sync

```bash
./scripts/publish-trunk-sync.sh patch   # or minor, major
```

Single command: builds, tests (unit + e2e), bumps version, publishes to npm, pushes to GitHub. Both distribution channels (npm package + marketplace plugin) updated together.

## License

MIT
