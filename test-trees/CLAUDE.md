# test-trees

Claude Code plugin that enforces test-driven development via the `tdd` skill.

## Requirements

### Functional
- **`tdd` skill** — auto-triggers when Claude changes behaviour, interfaces, or tests. Enforces red/green/refactor TDD cycle with human-readable test tree output that reads as a specification of operating principles.
- **`setup-test-trees` skill** — user-invoked (`/setup-test-trees`). Reviews the project, identifies and suggests candidate test frameworks, determines how `tdd` skill conventions apply, configures tree-style reporter output, sets up a changed-test runner for fast TDD feedback, updates the project's CLAUDE.md with concrete test commands, and verifies it works.

### Cross-functional
- Skills are pure Markdown — no runtime code, no dependencies.
- Plugin must work when installed via marketplace (`claude plugin install`).

## Mental Model

This is a **Claude Code plugin** — a bundle of skills that extend Claude's behaviour inside a user's project.

- **Plugin manifest** (`plugin.json`) registers the plugin name, version, and description with Claude Code.
- **Skills** are Markdown files (`SKILL.md`) containing instructions that Claude follows. Each skill has YAML frontmatter (`name`, `description`) and a Markdown body with rules and examples.
- The `tdd` skill has a `description` that tells Claude when to auto-trigger (behaviour/interface/test changes). It is not invoked via slash command.
- The `setup-test-trees` skill is invoked explicitly by the user. It references framework-specific configuration docs.
- **Marketplace metadata** (`marketplace.json`) registers the plugin owner and source for the plugin marketplace.
- There is no application code — the entire plugin is declarative Markdown and JSON config.

## Repo Map

```
CLAUDE.md                        — project instructions (this file)
README.md                        — agent-facing docs (Claude reads this)
.humans/README.md                — human-facing docs (users read this)
.claude-plugin/
  plugin.json                    — plugin manifest (name, version, description)
  marketplace.json               — marketplace registration (owner, source)
.claude/
  settings.json                  — enabled plugins for this project
skills/
  tdd/SKILL.md                   — TDD skill (auto-triggers on behaviour changes)
  setup-test-trees/SKILL.md       — setup skill (configures test framework reporter)
test/
  test_helper.bash               — shared helper (loads bats-support + bats-assert)
  *.bats                         — Bats test files
```

## Conventions

- The skill content in `SKILL.md` is the source of truth for TDD rules
- Plugin metadata lives in `.claude-plugin/plugin.json`
- Agent docs go in `README.md`, human docs go in `.humans/README.md`
- Tests use Bats (Bash Automated Testing System) — run with `bats --pretty test/`
- Test helpers (bats-support, bats-assert) are npm devDependencies loaded via `test/test_helper.bash`
