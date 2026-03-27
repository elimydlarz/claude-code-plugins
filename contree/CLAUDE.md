# CLAUDE.md

## What This Is

A Claude Code plugin that unifies test-tree-driven development with living requirements. Test trees ARE the requirements — they live in `## Requirements` of the project's CLAUDE.md, describe what the system does using `when/then` specifications, and are kept in sync with implementation automatically.

Three mechanisms:

1. **tdd skill** — auto-triggers on behaviour changes. Enforces outside-in TDD (functional test → unit TDD → functional pass) where every test traces back to a requirement tree in CLAUDE.md.

2. **setup-contree skill** — user-invoked. Configures test framework with tree reporters, generates initial requirement trees from existing code/plans, writes them to CLAUDE.md.

3. **sync-to-requirements skill** — user-invoked. Audits implementation against requirement trees — finds gaps, untested paths, undocumented behaviour, stale requirements. Fixes drift.

4. **Stop hook** — fires after every response, prompting Claude to keep requirement trees, mental model, and repo map in CLAUDE.md current.

## Mental Model

Test trees serve dual purpose: they are both the specification (in CLAUDE.md) and the test structure (in code). The requirement trees in `## Requirements` use `when/then` format describing operating principles. The `tdd` skill implements against these trees. The `sync-to-requirements` skill verifies completeness. The stop hook ensures continuous maintenance.

Flow: `setup-contree` → generates requirement trees → `tdd` implements them → stop hook maintains them → `sync-to-requirements` audits completeness.

## Repo Map

- `CLAUDE.md` — this file
- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `package.json` — dev dependencies (bats-support, bats-assert) and test scripts
- `rules/` — coding principles (one rule per file, plain prose, no frontmatter)
- `hooks/hooks.json` — Stop hook prompting CLAUDE.md updates (requirement trees, mental model, repo map)
- `skills/tdd/SKILL.md` — outside-in TDD skill, auto-triggers on behaviour changes
- `skills/setup-contree/SKILL.md` — project setup: test framework config + initial requirement tree generation
- `skills/sync-to-requirements/SKILL.md` — completeness audit: requirements vs implementation
- `test/plugin.bats` — structural tests: plugin manifest, skill files, frontmatter
- `test/hook.bats` — hook behaviour tests: loop prevention, exit codes, prompt content
- `test/functional/run.sh` — functional tests: runs Claude with contree loaded against seed project
- `test/fixtures/seed-project/` — tiny JS counter module used as test target

## Requirements

### test-trees-as-requirements

```
test-trees-as-requirements
  when a project uses contree
    then requirements in CLAUDE.md are test trees in when/then format
    and each capability has its own subsection under ## Requirements
  when a behaviour change is needed
    then the requirement tree must exist before implementation starts
  when implementation reveals new understanding
    then the requirement tree is updated to reflect reality
```

### outside-in-tdd

```
outside-in-tdd
  when implementing a requirement
    then start with a failing functional test matching a when/then path
    and TDD inward through unit layers
    and only one failing test exists at the current layer at a time
  when all unit tests pass
    then the functional test should pass
  when all behaviours are complete
    then run mutation testing as final validation
```

### stop-hook-sync

```
stop-hook-sync
  when Claude stops after any response
    then it checks whether requirement trees need updating
    and checks whether mental model needs updating
    and checks whether repo map needs updating
  when stop_hook_active is true
    then the hook exits silently to prevent infinite loops
  when nothing needs updating
    then Claude replies with 0
```

### setup-generates-trees

```
setup-generates-trees
  when setup-contree is run on an existing project
    then existing test config is detected and merged into, not overwritten
    and tree reporters are configured for both local dev and CI (dual reporters)
    and unit and functional test layers are configured as separate commands
    and mutation testing is configured with explicit test file exclusions
    and changed-test runners are configured with known gotchas addressed
    and requirement trees are generated from existing code
    and trees are written to ## Requirements in CLAUDE.md
  when setup-contree is run on a new project
    then requirement trees are generated from user-described plans
    and tests are NOT implemented yet
  when the language only supports flat test output
    then the best available option is configured
    and the limitation is communicated honestly
  when tests are colocated with source
    then mutation testing mutate globs explicitly exclude test file patterns
```

### sync-completes-and-implements

```
sync-completes-and-implements
  when sync-to-requirements is run
    then every when/then path is checked for implementation and tests
    and undocumented behaviour gets new requirement trees in CLAUDE.md
    and incomplete trees are extended with missing when/then paths
    and stale requirements are removed
  when gaps exist after trees are completed
    then each gap is implemented using the tdd skill's outside-in cycle
  when all gaps are implemented
    then every when/then path has a passing functional test
```

### composable-testing

```
composable-testing
  when a project uses contree
    then functional tests go in test/functional/ at project root
    and unit tests are colocated with source
    and both layers produce tree-shaped output
    and mutation testing validates unit test quality
```

## Dependencies

The stop hook requires `jq` on the host system.
