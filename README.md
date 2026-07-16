# elimydlarz — Claude Code and Codex Plugins

Tools for working with Claude Code and Codex: parallel agent coordination, test-driven development, living documentation, and shared coding rules.

## Setup

Add the plugin marketplace:

```sh
claude plugin marketplace add elimydlarz/claude-code-plugins
codex plugin marketplace add elimydlarz/claude-code-plugins
```

Then install what you need:

| Tool | Install | What it does |
|------|---------|--------------|
| [trunk-sync](trunk-sync/README.md) | Claude: `claude plugin install trunk-sync@elimydlarz` — Codex: `codex plugin add trunk-sync@elimydlarz` | Continuously commit and synchronize agent edits on the checked-out branch |
| [contree](contree/README.md) | Claude: `claude plugin install contree@elimydlarz` — Codex: `codex plugin add contree@elimydlarz` | Test trees as living requirements — TDD with auto-synced specs in TEST_TREES.md |

Integration surface notes live in [CLAUDE_CODE_INTERFACE.md](CLAUDE_CODE_INTERFACE.md) and [CODEX_INTERFACE.md](CODEX_INTERFACE.md).

---

## Publishing (maintainers)

Releases are published from the repository root. Review the product's changes since its latest tag, write release notes, and choose `patch`, `minor`, or `major`:

```bash
pnpm publish:contree patch --notes-file /tmp/contree-notes.md
pnpm publish:trunk-sync patch --notes-file /tmp/trunk-sync-notes.md
```

The notes file is required. Running either command without it fails and prints the exact `git log` command for reviewing changes since that product's previous tag.

Both commands require a semantic version change kind, bump the Claude Code and Codex plugin manifests, commit and tag the release, atomically push the release commit and tag, and then create a GitHub release. If the atomic push is rejected, the publisher restores the pre-release local commit, tag, artifacts, manifests, and index so the same bump can be retried. The Trunk Sync publisher first builds and commits its tracked marketplace runtime. Neither publisher runs tests. The Contree publisher refreshes its Claude Code marketplace installation after publishing.

## License

MIT
