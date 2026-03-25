# test-trees

Claude Code plugin that enforces outside-in TDD with test trees at every layer — unit, functional, and mutation testing.

## Requirements

### Functional
- **outside-in-tdd** — `tdd` skill instructs Claude to follow outside-in TDD when changing behaviour, interfaces, or tests. Enforces: failing functional test first → TDD through unit layers → functional test passes → refactor. Mutation testing runs only at the end of completed work, not during the cycle.
- **test-tree-output** — all test layers produce nested, indented, human-readable tree output that reads as a specification of operating principles.
- **three-layer-testing** — `setup-test-trees` skill configures unit tests (colocated `*.unit.test.*`), functional tests (`test/functional/*.functional.test.*`), and Stryker mutation testing against unit tests.
- **fast-feedback** — `setup-test-trees` configures changed-test runners at each layer for tight TDD loops.
- **project-onboarding** — `setup-test-trees` updates the target project's CLAUDE.md with concrete test commands and the outside-in workflow.

### Cross-functional
- **pure-markdown** — skills are declarative Markdown, no runtime code or dependencies.
- **marketplace-install** — plugin works when installed via `claude plugin install` from the marketplace.

## Mental Model

This is a **Claude Code plugin** — declarative Markdown skills (no application code) that extend Claude's behaviour inside a user's project.

- **Three test layers:** Functional tests (real system, no mocks, `test/functional/`) prove behaviour works end-to-end. Unit tests (colocated, mocked collaborators) drive internal design. Stryker mutation testing validates that unit tests assert meaningful behaviour.
- **Outside-in flow:** Every behaviour change starts with a failing functional test, drops to unit-level TDD to build the implementation inward, then rises back up to pass the functional test. This ensures you only build what's needed and catch integration gaps early.
- **Test trees as specification:** Test output at every layer is nested, indented, tree-shaped — describing *operating principles* (not enumerating cases). These trees are the contract for what the software does.
- **Two skills:** `tdd` instructs Claude to follow the outside-in cycle when changing behaviour/interfaces/tests (via its frontmatter `description` field — a relevance hint, not a mechanical trigger). `setup-test-trees` is user-invoked to configure a project's test infrastructure across all three layers.
- **Plugin structure:** `plugin.json` manifest, `marketplace.json` metadata, `SKILL.md` files with YAML frontmatter. Distributed via the Claude Code plugin marketplace.

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
  tdd/SKILL.md                   — outside-in TDD enforcement (auto-triggers on behaviour changes)
  setup-test-trees/SKILL.md       — project setup (unit + functional + Stryker + tree reporters)
  plan-test-trees/SKILL.md        — plan test trees before writing code (auto-triggers on planning/design)
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
