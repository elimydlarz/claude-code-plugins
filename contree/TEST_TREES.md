## test-trees-as-requirements

```
test-trees-as-requirements (test/test-trees-as-requirements.bats)
  when a project uses contree
    then CLAUDE.md identifies TEST_TREES.md as the definition of functional and cross-functional requirements
    and TEST_TREES.md defines functional requirements using EARS syntax
    and each behavioural unit has its own tree in TEST_TREES.md
    and trees are flat subsections — not grouped by kind or layer
    and every tree reifies exactly one test file
    and every test file reifies exactly one tree
    and every tree names the file path(s) it reifies to — at minimum its test file path; its source file path also where the tree maps 1:1 to one
    and the EARS rule is embedded in skills that use it
  when a behaviour change is needed
    then the tree must exist before implementation starts
  when implementation reveals new understanding
    then the tree is updated to reflect reality
```

## setup-scaffolds-mental-model

```
setup-scaffolds-mental-model (skills/setup/SKILL.md, test/setup-scaffolds-mental-model.bats)
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

## outside-in-tdd

```
outside-in-tdd (skills/tdd/SKILL.md, test/outside-in-tdd.bats)
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
  when TDD creates a test or source file at a path the tree does not yet name
    then the tree's parenthesised paths are updated to include the new file before moving to the next test
  when TDD moves or renames a file that a tree names
    then the tree's parenthesised paths are updated to reflect the new location in the same step as the move
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

## pre-task-hook

```
pre-task-hook (hooks/session-start.sh, test/pre-task-hook.bats)
  when a session starts
    then MENTAL_MODEL.md contents are displayed
    and TEST_TREES.md contents are displayed
    and the agent is directed to use the mental model's existing concepts, vocabulary, and decisions rather than inventing parallel ones
    and the agent is directed to preserve the mental model's invariants, surfacing conflict when a task appears to require breaking one rather than routing around it
    and the agent is directed to flag the mental model as wrong, incomplete, or misleading rather than silently reshaping it through code
    and the agent is directed to treat test trees as the authoritative behaviour contract
    and the agent is directed to eagerly use the listed skills to fulfil operator requests where applicable
    and the agent is directed to use the change skill for any behaviour change, before any code is discussed or written
    and the agent is directed to use the tdd skill when implementing behaviour, writing code, or writing tests
    and the agent is directed to use the sync skill when asked about drift, gaps, staleness, or completeness
    and the agent is directed to use the setup skill when no test framework is configured or TEST_TREES.md is absent
    and the agent is directed to use the workflow skill for the full arc from idea to verified working software
```

## post-task-hook

```
post-task-hook (hooks/stop-drift-check.sh, test/post-task-hook.bats)
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

## post-update-hook

```
post-update-hook (hooks/post-update-check.sh, test/post-update-hook.bats)
  when MENTAL_MODEL.md is edited via a tool call
    then the validator runs against the post-edit content
    and its findings are surfaced to Claude's next response via additional context
  when a file other than MENTAL_MODEL.md is edited
    then the validator does not run
```

## mental-model-validator

```
mental-model-validator (hooks/validate-mental-model.sh, test/mental-model-validator.bats)
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

## setup-generates-trees

```
setup-generates-trees (skills/setup/SKILL.md, test/setup-generates-trees.bats)
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

## setup-installs-architectural-linter

```
setup-installs-architectural-linter (skills/setup/SKILL.md, test/setup-installs-architectural-linter.bats)
  when setup is run
    then a hex-boundary linter is installed and configured
```

## change-writes-trees

```
change-writes-trees (skills/change/SKILL.md, test/change-writes-trees.bats)
  when a behaviour change is needed
    then the change is discussed with the user before modifying trees
    and EARS patterns are chosen to match each requirement's nature
    and every then clause asserts something the when clause does not already imply
    and System → inner-layer decomposition is planned, one tree per behavioural unit
    and every tree's paths map verbatim to a describe/it hierarchy in one test file
  when an Adapter or System tree is written
    then paths use the consumer's vocabulary, not implementation internals
    and paths describe principles, not enumerated cases
  when a Domain, Use-case, or Port-contract tree is written
    then top-level nodes name the unit's exported functions, methods, or port operations
    and each path corresponds to an observable branch in the unit
  when a tree is written
    then its file path(s) are named in parentheses at the end of the tree name line — the test file it reifies to, and any source file it maps 1:1 to
    and if naming a (sub)tree's path reveals an awkward shape, the tree or implementation is reshaped — the path is not stripped to hide the mismatch
  when modifying existing behaviour
    then only affected paths are changed
  when removing a capability
    then the tree is removed after user confirmation
  when trees are complete
    then they are presented to the user for alignment
    and the user is suggested to run sync
```

## change-decomposes-across-layers

```
change-decomposes-across-layers (skills/change/SKILL.md, test/change-decomposes-across-layers.bats)
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

## sync-audits-and-resolves

```
sync-audits-and-resolves (skills/sync/SKILL.md, test/sync-audits-and-resolves.bats)
  when sync is run
    then every when/then path is checked for implementation and tests
    and each test file's describe/it hierarchy is parsed and compared to its tree
    and each tree's named file paths are verified against the filesystem
    and drift between trees and implementation is identified
  when implementation exists without a tree
    then it is discussed with the user — may need a tree or may need removing
  when a tree exists without implementation
    then it is flagged as a gap to implement
  when a tree's named path does not exist on disk
    then it is flagged as drift
  when a test file's describe/it hierarchy disagrees with its tree
    then both are presented to the user for resolution
    and sync does not pick a side
  when stale trees or dead paths are found
    then they are discussed with the user before removal
  when gaps are identified
    then the user is suggested to run tdd to implement them
```

## workflow-runs-end-to-end

```
workflow-runs-end-to-end (skills/workflow/SKILL.md, test/workflow-runs-end-to-end.bats)
  when workflow is run with an idea
    then change, sync, and tdd run in sequence without pausing
  when change completes
    then sync runs immediately
  when sync identifies gaps
    then tdd implements each gap immediately
  when all gaps are implemented
    then all test trees have passing tests
```

## skill-discoverability

```
skill-discoverability (hooks/session-start.sh, test/skill-discoverability.bats)
  when a user describes a behaviour change without naming a skill
    then the change skill is triggered
  when a user asks about drift between code and requirements without naming a skill
    then the sync skill is triggered
  when a user asks to set up testing without naming a skill
    then the setup skill is triggered
  when a user asks to implement from existing requirements without naming a skill
    then the tdd skill is triggered
```

## composable-testing

```
composable-testing (skills/setup/SKILL.md, test/composable-testing.bats)
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

## pressure-phrase-on-session-start

```
pressure-phrase-on-session-start (hooks/pressure-phrases.sh, test/pressure-phrases.bats)
  when a session starts
    then one pressure phrase is appended to the rules output
    and the phrase is randomly drawn from the pressure-phrase pool in hooks/pressure-phrases.sh
  then the pressure-phrase pool spans tip-framing, career-stakes, boss-watching, and urgency registers
  then phrases vary in wording across the pool
```

## rules-loading

```
rules-loading (hooks/session-start.sh, test/rules-loading.bats)
  when a session starts
    then the rules list is shown
    and not repeated on every response
```

## self-care-20-20-20

```
self-care-20-20-20 (hooks/self-care-20-20-20.sh, test/self-care.bats)
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
