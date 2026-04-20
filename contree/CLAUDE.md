# CLAUDE.md

## What This Is

A Claude Code plugin that unifies test-tree-driven development with living requirements. Test trees ARE the requirements — they live in `## Test Trees` of the project's CLAUDE.md, describe what the system does using EARS syntax, and are kept in sync with implementation automatically.

Mechanisms:

- **Rules** — coding principles printed by the SessionStart hook (simplicity, expressiveness, fail-fast, no fake code, etc.). The rules list lives inline in `hooks/session-start.sh` so it ships with the plugin install.
- **setup skill** — prepare the project for ongoing test-tree-driven development. Configures test framework with tree reporters, generates initial test trees, establishes the contract.
- **change skill** — set expected behaviour. Talks through the change, writes or modifies test trees before code exists.
- **sync skill** — identify gaps and cruft. Compares test trees against implementation in both directions — surfaces drift, staleness, and missing coverage.
- **tdd skill** — close gaps. Outside-in TDD where every test traces back to a test tree — one failing test at a time until the contract is fulfilled.
- **workflow skill** — the full arc. Runs `change` → `sync` → `tdd` end to end — from idea to verified working software.
- **Stop hook** — guard the contract. Fires after every response, detecting drift between intent and implementation. Yields the turn silently when the response ends with a question, so questions to the user aren't buried under drift-check output.
- **Pressure phrase** — inject motivation. The SessionStart hook prints one random pressure phrase (tip-framing, career-stakes, boss-watching, or urgency) alongside the rules, so the agent starts every session under a little stage-light.
- **Self-care hook** — nudge the user. Fires on each `UserPromptSubmit` in any session; records a shared heartbeat and, after 20 minutes of continuous interaction (no gap longer than 5 minutes between heartbeats across any sessions), injects a 20-20-20 eye-break reminder into Claude's context via `additionalContext` so Claude opens its response with the nudge.

## Mental Model

Test trees are the living contract between intent and implementation — both the specification (in CLAUDE.md) and the test structure (in code). They use EARS syntax to choose the right keyword for each requirement — `when` for events, `while` for state, `if/then` for errors, `where` for optional features, bare `then` for ubiquitous constraints. When one behaviour depends on another's outcome, it nests under that outcome (causal nesting) — not as a sibling. Contree prescribes **hexagonal architecture** with dependencies pointing inward and a strict linter (dependency-cruiser for JS/TS) enforcing the boundaries. Tests are layered by architectural seam: **Domain**, **Use-case**, **Adapter** (driving and driven), and **System**. Each driven port ships with an in-memory twin so Use-case and System tests run fast; a shared port contract suite is imported by both the in-memory adapter's test file and the real adapter's test file, making substitution sound. Every behavioural unit gets its own tree in `## Test Trees`; every tree reifies exactly one test file. See `skills/tdd/SKILL.md` for the full framing. `change` sets expected behaviour. `sync` identifies where reality has drifted. `tdd` closes gaps. The stop hook guards the contract — drift is never resolved silently. Coding rules enforce principles (simplicity, expressiveness, fail-fast) across all work.

Flow: `setup` prepares the project for test-tree-driven development → `change` sets expected behaviour → `sync` identifies gaps and cruft → `tdd` closes gaps. Or use `workflow` for the full arc without pausing. The stop hook guards the contract throughout. The SessionStart hook bundles a pressure phrase with the rules to keep the agent sharp. The self-care hook nudges the user to take eye breaks via the 20-20-20 rule. Rules apply always.

## Repo Map

- `CLAUDE.md` — this file
- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `package.json` — dev dependencies (bats-support, bats-assert) and test scripts
- `hooks/hooks.json` — SessionStart hook printing rules plus a pressure phrase; Stop hook detecting drift; UserPromptSubmit self-care hook
- `hooks/session-start.sh` — SessionStart hook: prints the inline rules list plus one random pressure phrase (also inline) to stdout
- `hooks/stop-drift-check.sh` — Stop hook: injects drift-check prompt unless Claude's last response ends with a question, in which case it yields the turn to the user
- `hooks/self-care-20-20-20.sh` — UserPromptSubmit hook: reminds user of the 20-20-20 rule after 20 min of keyboard time
- `skills/setup/SKILL.md` — prepare the project for test-tree-driven development: framework, reporters, initial trees
- `skills/change/SKILL.md` — set expected behaviour: write or modify test trees before code exists
- `skills/sync/SKILL.md` — identify gaps and cruft: test trees vs implementation in both directions
- `skills/tdd/SKILL.md` — close gaps: outside-in TDD, one failing test at a time
- `skills/workflow/SKILL.md` — the full arc: idea → contract → verified implementation
- `test/plugin.bats` — structural tests: plugin manifest, skill files, frontmatter
- `test/hook.bats` — hook behaviour tests: loop prevention, exit codes, prompt content
- `test/self-care.bats` — self-care hook tests: nudge timing, file creation, error handling
- `test/functional/Dockerfile` — Docker image for functional tests (node + git + jq + claude CLI, fixture deps pre-installed)
- `test/functional/docker-run.sh` — runs functional tests in Docker (parallel), passes secrets via env vars
- `test/functional/docker-entrypoint.sh` — test cases with VERIFY criteria; transcripts saved as JSONL and analysed by Claude directly
- `test/fixtures/seed-project/` — tiny JS counter module used as test target
- `test/fixtures/incidental-pass/` — counter with reset() pre-implemented (for incidental-pass test)
- `test/fixtures/sync-drift/` — counter with deliberate drift (amount param without tree, decrement tree without impl)
- `test/fixtures/tdd-ready/` — counter with vitest configured + requirements, no tests
- `test/fixtures/ears-project/` — media player module for EARS pattern functional test

## Functional Testing

Run functional tests with `pnpm test:functional` (all) or `bash test/functional/docker-run.sh <test-name>` (one). After the script finishes, it prints the exact transcript file paths. **Always read the transcripts and evaluate each against the VERIFY criteria in docker-entrypoint.sh.** Report PASS/FAIL per criterion with evidence.

## Test Trees

### test-trees-as-requirements

```
test-trees-as-requirements
  when a project uses contree
    then CLAUDE.md identifies TEST_TREES.md as the definition of functional and cross-functional requirements
    and TEST_TREES.md defines functional requirements using EARS syntax
    and each behavioural unit has its own tree in TEST_TREES.md
    and trees are flat subsections — not grouped by kind or layer
    and every tree reifies exactly one test file
    and every test file reifies exactly one tree
    and the EARS rule is embedded in skills that use it
  when a behaviour change is needed
    then the tree must exist before implementation starts
  when implementation reveals new understanding
    then the tree is updated to reflect reality
```

### setup-scaffolds-mental-model

```
setup-scaffolds-mental-model
  when setup is run and MENTAL_MODEL.md does not exist
    then MENTAL_MODEL.md is created with seven H2 sections
    and the seven sections are: Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, Temporal View
    and each section is followed by a one-line placeholder describing what belongs there
  when setup is run and MENTAL_MODEL.md already exists
    then its content is not modified
  when setup is run and CLAUDE.md does not reference MENTAL_MODEL.md
    then a pointer line is added to CLAUDE.md identifying MENTAL_MODEL.md as the definition of the mental model
  when setup is run and CLAUDE.md already references MENTAL_MODEL.md
    then the pointer is not duplicated
```

### outside-in-tdd

```
outside-in-tdd
  when implementing a tree
    then each when/then path becomes one failing test, written one at a time in tree order
    and the test is written at the tree's layer (Domain / Use-case / Adapter / System)
    and the test file reifies the tree — describe/it hierarchy mirrors when/then verbatim
    and existing trees are not modified silently
  when writing a Use-case test
    then the in-memory adapter for each outbound port is wired
  when writing an Adapter test for an in-memory or real driven adapter
    then the shared port contract suite is imported and run against the adapter
  when writing an Adapter test for a real driven adapter
    then real infrastructure is exercised
    and adapter-specific tests are added for behaviour beyond the shared contract
  when TDD discovers new test cases
    then new cases are added to the tree
    but existing when/then paths are not changed or removed
  when an expected-red test passes incidentally
    then break the implementation intentionally
    and observe the test failing
    then fix the implementation, observe the test passing, and move on
  when all inner-layer tests pass
    then the System test passes
  when all trees for a slice have passing tests
    then run mutation testing against Domain and Use-case layers as final validation
    and suggest the user runs sync
  if no tree covers the behaviour
    then suggest the user runs change first
```

### pre-task-hook

```
pre-task-hook
  when a session starts
    then MENTAL_MODEL.md contents are displayed
    and TEST_TREES.md contents are displayed
    and the agent is directed to use the mental model's existing concepts, vocabulary, and decisions rather than inventing parallel ones
    and the agent is directed to preserve the mental model's invariants, surfacing conflict when a task appears to require breaking one rather than routing around it
    and the agent is directed to flag the mental model as wrong, incomplete, or misleading rather than silently reshaping it through code
    and the agent is directed to treat test trees as the authoritative behaviour contract
```

### post-task-hook

```
post-task-hook
  when Claude stops after a response that does not end with a question
    then a mental-model nudge prompts consideration of whether the task revealed something a future agent could not recover from code and tests, and whose removal would cause a mistake a competent human would not make, defaulting to no change
      when a change is warranted
        then the edit declares which of the seven sections it belongs to
        and an edit fitting no section is not added to the mental model
        and tightening an existing line is preferred over adding a new one
        and statements describe what is true, not what to avoid
        and when the target section is at its cap, an existing item is displaced or merged rather than appended
    and a test-trees nudge prompts detection of drift between trees and implementation
    and a claude-md nudge prompts detection of drift between CLAUDE.md content and reality
    and a readme nudge prompts detection of readme staleness
  when Claude stops after a response that ends with a question
    then the hook yields the turn to the user without injecting the nudges
  when stop_hook_active is true
    then the hook exits silently to prevent infinite loops
  when no nudge reports anything
    then Claude replies with 0
```

### post-update-hook

```
post-update-hook
  when MENTAL_MODEL.md is edited via a tool call
    then the validator runs against the post-edit content
    and its findings are surfaced to Claude's next response via additional context
  when a file other than MENTAL_MODEL.md is edited
    then the validator does not run
```

### mental-model-validator

```
mental-model-validator
  then the validator's output is advisory and does not block edits
  when MENTAL_MODEL.md is well-formed
    then the validator reports no issues
  when a section exceeds the upper bound of its cap range
    then the validator flags the overflow and names the section
  when MENTAL_MODEL.md contains a heading that is not one of the seven named sections
    then the validator flags the rogue heading
  when one of the seven named sections is missing
    then the validator flags the missing section
  when MENTAL_MODEL.md does not exist
    then the validator flags that the file is missing
```

### setup-generates-trees

```
setup-generates-trees
  when setup is run on an existing project
    then existing test config is detected and merged into, not overwritten
    and tree reporters are configured for both local dev and CI (dual reporters)
    and the four test layers (Domain, Use-case, Adapter, System) are configured as separate commands
    and mutation testing is configured with explicit test file exclusions for every layer's suffix
    and changed-test runners are configured with known gotchas addressed
    and test trees are generated from existing code
    and trees are written to TEST_TREES.md
    and CLAUDE.md is updated to point at TEST_TREES.md if it does not already
  when setup is run on a new project
    then test trees are generated from user-described plans
    and tests are NOT implemented yet
  when the language only supports flat test output
    then the best available option is configured
    and the limitation is communicated honestly
  when tests are colocated with source
    then mutation testing mutate globs explicitly exclude test file patterns
  when the project needs external services for Adapter or System tests
    then those layers run in Docker
    and test artefacts are torn down afterwards
    and secrets are passed via environment variables
```

### setup-installs-architectural-linter

```
setup-installs-architectural-linter
  when setup is run
    then a hex-boundary linter is installed and configured
```

### change-writes-trees

```
change-writes-trees
  when a behaviour change is needed
    then the change is discussed with the user before modifying trees
    and test trees are written from the consumer's perspective
    and EARS patterns are chosen to match each requirement's nature
    and every then clause asserts something the when clause does not already imply
    and System → inner-layer decomposition is planned, one tree per behavioural unit
  when modifying existing behaviour
    then only affected paths are changed
  when removing a capability
    then the tree is removed after user confirmation
  when trees are complete
    then they are presented to the user for alignment
    and the user is suggested to run sync
```

### change-decomposes-across-layers

```
change-decomposes-across-layers
  when a behaviour change is planned
    then the slice is captured as a System tree named for the consumer capability
    and each behavioural unit with observable choices becomes its own tree at its layer: Domain, Use-case, Adapter, or port contract
    and every tree reifies exactly one test file
    and trees are named for the subject with observable behaviour at their layer
  when a side effect is identified
    then it becomes an outbound port named for capability, not technology
    and the port ships in two flavours: an in-memory adapter and a real adapter
    and a shared contract suite is written for the port
    and both adapters must pass the shared suite
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

### skill-discoverability

```
skill-discoverability
  when a user describes a behaviour change without naming a skill
    then the change skill is triggered
  when a user asks about drift between code and requirements without naming a skill
    then the sync skill is triggered
  when a user asks to set up testing without naming a skill
    then the setup skill is triggered
  when a user asks to implement from existing requirements without naming a skill
    then the tdd skill is triggered
```

### composable-testing

```
composable-testing
  when a project uses contree
    then Domain tests are colocated with source (*.domain.test.*)
    and Use-case tests are colocated with the use-case (*.use-case.test.*)
    and Adapter tests are colocated with the adapter — driving or driven (*.adapter.test.*)
    and System tests live under test/system/ (*.system.test.*)
    and each outbound port has an in-memory adapter used by Use-case and System tests
    and each outbound port has a shared contract suite imported by both in-memory and real adapter tests
    and every layer produces tree-shaped output
    and mutation testing validates quality at the Domain and Use-case layers
```

### pressure-phrase-on-session-start

```
pressure-phrase-on-session-start
  when a session starts
    then one pressure phrase is appended to the rules output
    and the phrase is randomly drawn from the inline pressure-phrase pool
  then the pressure-phrase pool spans tip-framing, career-stakes, boss-watching, and urgency registers
  then phrases vary in wording across the pool
```

### rules-loading

```
rules-loading
  when a session starts
    then the rules list is shown
    and not repeated on every response
```

### self-care-20-20-20

```
self-care-20-20-20
  when the UserPromptSubmit hook fires in any session
    when the heartbeat is recorded
      then heartbeats older than one hour are pruned
      and while heartbeats with no gap longer than 5 minutes between them have been continuous for at least 20 minutes
        and no reminder has been issued in the last 20 minutes
          when a reminder is recorded
            then the hook returns additionalContext instructing Claude to open its response with the 20-20-20 reminder before addressing the request
            and the instructed reminder names the rule and the action: look 20 feet away for 20 seconds
          when the reminder record fails
            then the hook exits silently
    when the heartbeat record fails
      then the hook exits silently
```

## Cross-Functional Requirements

- Supported languages: JS/TS (Node, Bun, React, React Native), Elixir (Phoenix, Jido), Go. Setup refuses other languages and names the supported set.
- Mutation testing is omitted for Elixir — no mature tool exists. Users are pointed at property-based testing with StreamData as a substitute.

## Dependencies

The stop hook requires `jq` on the host system.
