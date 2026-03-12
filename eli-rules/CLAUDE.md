# eli-rules

NPM package that syncs reusable Claude Code rules into consuming projects.

## Requirements

- **postinstall-sync**: On `postinstall`, all rules are copied to the consumer's `.claude/rules/` directory
- **namespaced-filenames**: Synced files are prefixed with the package name (e.g. `susu-eng--eli-rules--kiss.md`) to avoid collisions
- **create-if-missing**: Rules that don't exist in the target are created
- **update-in-place**: Rules that already exist in the target are overwritten with the latest version
- **ignore-unknown**: Files in `.claude/rules/` not namespaced to this package are left untouched
- **cli-sync**: A `eli-rules-sync` bin command allows manual re-sync outside of postinstall

## Mental Model

An NPM package (`@susu-eng/eli-rules`) installed as a dev dependency. Published to the `@susu-eng` org. On `postinstall`, `sync.mjs` copies rule files from `rules/` into the consuming project's `.claude/rules/` directory with namespaced filenames (e.g. `susu-eng--eli-rules--kiss.md`). The namespace prefix is derived from `package.json` `name`. Sync creates/updates namespaced rules and ignores unknown files, making it safe alongside other rules. `prepublishOnly` runs `build` before every publish.

## Repo Map

- `rules/` — Source rule files, one principle per file (e.g. `kiss.md`, `verification.md`)
- `sync.mjs` — Sync script: copies rules to consumer's `.claude/rules/` with namespaced filenames
- `sync.test.mjs` — Integration tests for sync.mjs (runs script as subprocess against temp dirs)
- `vitest.config.ts` — Vitest config with tree reporter for nested output
- `package.json` — Package manifest with `postinstall` hook and `bin` entry

## Conventions

- One rule per file in `rules/`, named with a short kebab-case key
- Plain prose, no frontmatter or headings
- Keep rules concise and direct
