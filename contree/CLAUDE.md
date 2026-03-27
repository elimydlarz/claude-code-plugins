# CLAUDE.md

## What This Is

A Claude Code plugin that unifies test-tree-driven development with living requirements. Test trees ARE the requirements — they live in `## Requirements` of the project's CLAUDE.md, describe what the system does using `when/then` specifications, and are kept in sync with implementation automatically.

Mechanisms:

- **Rules** — coding principles loaded automatically when the plugin is active (simplicity, expressiveness, fail-fast, no fake code, etc.).
- **setup skill** — prepare the project for ongoing test-tree-driven development. Configures test framework with tree reporters, generates initial test trees, establishes the contract.
- **change skill** — set expected behaviour. Talks through the change, writes or modifies test trees before code exists.
- **sync skill** — identify gaps and cruft. Compares test trees against implementation in both directions — surfaces drift, staleness, and missing coverage.
- **tdd skill** — close gaps. Outside-in TDD where every test traces back to a test tree — one failing test at a time until the contract is fulfilled.
- **workflow skill** — the full arc. Runs `change` → `sync` → `tdd` end to end — from idea to verified working software.
- **Stop hook** — guard the contract. Fires after every response, detecting drift between intent and implementation.

## Mental Model

Test trees are the living contract between intent and implementation — both the specification (in CLAUDE.md) and the test structure (in code). They use `when/then` format describing operating principles. `change` sets expected behaviour. `sync` identifies where reality has drifted. `tdd` closes gaps. The stop hook guards the contract — drift is never resolved silently. Coding rules enforce principles (simplicity, expressiveness, fail-fast) across all work.

Flow: `setup` → configures test infrastructure → `change` writes/modifies test trees → `sync` audits and identifies gaps → `tdd` implements gaps. Or use `workflow` to run the full sequence without pausing. Stop hook detects drift and maintains mental model. Rules apply throughout.

## Repo Map

- `CLAUDE.md` — this file
- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `package.json` — dev dependencies (bats-support, bats-assert) and test scripts
- `rules/` — coding principles (one rule per file, plain prose, no frontmatter)
- `hooks/hooks.json` — Stop hook detecting drift and prompting mental model updates
- `skills/setup/SKILL.md` — project setup: test framework config + initial test tree generation
- `skills/change/SKILL.md` — write or modify test trees in CLAUDE.md, plan decomposition
- `skills/sync/SKILL.md` — completeness audit: test trees vs implementation, TDD gaps
- `skills/tdd/SKILL.md` — outside-in TDD skill, auto-triggers when implementing behaviour
- `skills/workflow/SKILL.md` — end-to-end: runs change → sync → tdd without pausing
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
    then the test tree must exist before implementation starts
  when implementation reveals new understanding
    then the test tree is updated to reflect reality
```

### outside-in-tdd

```
outside-in-tdd
  when implementing a test tree
    then start with a failing functional test matching a when/then path
    and TDD inward through unit layers
    and only one failing test exists at the current layer at a time
    and existing test trees are not modified
  when TDD discovers new test cases
    then new cases are added to the tree
    but existing when/then paths are not changed or removed
  when no test tree covers the behaviour
    then suggest the user runs change first
  when all unit tests pass
    then the functional test should pass
  when all behaviours are complete
    then run mutation testing as final validation
    and suggest the user runs sync
```

### stop-hook-sync

```
stop-hook-sync
  when Claude stops after any response
    then it checks whether implementation has drifted from test trees
    and checks whether mental model needs updating
    and checks whether CLAUDE.md needs updating
    and checks whether README.md accurately describes the project
  when drift is detected between implementation and test trees
    then Claude asks the user: update test trees and tests to reflect implementation, or pare implementation back to match test trees
    and never modifies test trees silently
  when stop_hook_active is true
    then the hook exits silently to prevent infinite loops
  when nothing needs attention
    then Claude replies with 0
```

### setup-generates-trees

```
setup-generates-trees
  when setup is run on an existing project
    then existing test config is detected and merged into, not overwritten
    and tree reporters are configured for both local dev and CI (dual reporters)
    and unit and functional test layers are configured as separate commands
    and mutation testing is configured with explicit test file exclusions
    and changed-test runners are configured with known gotchas addressed
    and test trees are generated from existing code
    and trees are written to ## Requirements in CLAUDE.md
  when setup is run on a new project
    then test trees are generated from user-described plans
    and tests are NOT implemented yet
  when the language only supports flat test output
    then the best available option is configured
    and the limitation is communicated honestly
  when tests are colocated with source
    then mutation testing mutate globs explicitly exclude test file patterns
```

### change-writes-trees

```
change-writes-trees
  when a behaviour change is needed
    then the change is discussed with the user before modifying trees
    and test trees are written from the consumer's perspective
    and functional → unit decomposition is planned
  when modifying existing behaviour
    then only affected when/then paths are changed
  when removing a capability
    then the tree is removed after user confirmation
  when trees are complete
    then they are presented to the user for alignment
    and the user is suggested to run sync
```

### sync-audits-and-resolves

```
sync-audits-and-resolves
  when sync is run
    then every when/then path is checked for implementation and tests
    and drift between trees and implementation is identified
  when implementation exists without a tree
    then it is discussed with the user — may need a tree or may need removing
  when a tree exists without implementation
    then it is flagged as a gap to implement
  when stale trees or dead paths are found
    then they are discussed with the user before removal
  when gaps are identified
    then the user is suggested to run tdd to implement them
```

### workflow-runs-end-to-end

```
workflow-runs-end-to-end
  when workflow is run with an idea
    then change, sync, and tdd run in sequence without pausing
  when change completes
    then sync runs immediately
  when sync identifies gaps
    then tdd implements each gap immediately
  when all gaps are implemented
    then all test trees have passing tests
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
