## test-trees-as-requirements

```
test-trees-as-requirements (system: test/test-trees-as-requirements.bats)
  when a project uses contree
    then CLAUDE.md identifies TEST_TREES.md as the definition of functional and cross-functional requirements
    and TEST_TREES.md defines functional requirements using EARS syntax
    and each behavioural unit has its own tree in TEST_TREES.md
    and trees are flat subsections — not grouped by kind or layer
    and every tree reifies exactly one test file
    and every test file reifies exactly one tree
    and every tree names its coverage in parenthesised labelled pairs on the tree-name line, covering the categories src, domain, use-case, adapter, component, system, journey
    and gaps are declared explicitly — "none" for expected-but-uncovered categories, omission for not-applicable ones
    and the EARS rule is embedded in skills that use it
  when a behaviour change is needed
    then the tree must exist before implementation starts
  when implementation reveals new understanding
    then the tree is updated to reflect reality
```

## setup-scaffolds-mental-model

```
setup-scaffolds-mental-model (src: skills/setup/SKILL.md; system: test/setup-scaffolds-mental-model.bats; journey: test/journey/docker-entrypoint.sh)
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
outside-in-tdd (src: skills/tdd/SKILL.md; system: test/outside-in-tdd.bats; journey: test/journey/docker-entrypoint.sh)
  when starting a new capability
    then the first failing test is the outermost the capability needs at the highest tolerable realism — a Journey test for a new user-visible arc, otherwise a System test — with real driving and driven adapters, real infrastructure, real boundaries
    and System and inner-layer trees and tests are added only as implementation pressure from that failing journey/functional test demands them
    and inner layers are not designed up front
  when implementing a tree
    then each when/then path becomes one failing test, written one at a time in tree order
    and the test is written at the tree's layer (Journey / System / Component / Adapter / Use-case / Domain)
    and the test file reifies the tree — describe/it hierarchy mirrors when/then verbatim
    and existing trees are not modified silently
  when writing a Journey test
    then real driving and driven adapters are wired across the multi-capability arc at max realism
    and the arc walks representative error paths, not every error, and eventually succeeds
    and the journey is curated and kept runnable in under 5 minutes, trimmed to the highest-impact and most-recent steps
  when writing a System test
    then real driving and driven adapters are wired whole-app for one capability at the highest tolerable realism — the same surface a Component test covers, validated against real infrastructure
    and System tests are selective, not exhaustive — real-everything is expensive, so it is spent on the highest-impact capabilities and expanded over time
    and when breadth at max realism is unaffordable, the journey is leaned on instead of wiring many in-memory System tests
  when writing a Component test
    then real driving and driven adapters are wired whole-app for one capability, with externals doubled only at the edge — an in-memory database and stubbed outbound HTTP
    and exhaustive single-capability behaviour coverage lives here, because doubling only the edges keeps it cheap enough to always write
  when breadth coverage is required
    then it is carried by the exhaustive cheap layers — Use-case and Component
  when writing a Use-case test
    then the in-memory adapter for each outbound port is wired
    and exhaustive single-behaviour orchestration coverage lives here, isolated from real adapters
  when writing an Adapter test for an in-memory or real driven adapter
    then the shared port contract suite is imported and run against the adapter
  when writing an Adapter test for a real driven adapter
    then real infrastructure is exercised
    and adapter-specific tests are added for behaviour beyond the shared contract
  when TDD discovers new test cases
    then new cases are added to the tree
    but existing when/then paths are not changed or removed
  when TDD creates a test or source file at a path the tree does not yet name
    then the tree's labelled parenthesised paths are updated to include the new file under its category before moving to the next test
    and any prior "none" value under that category is replaced with the new path
  when TDD moves or renames a file that a tree names
    then the tree's labelled parenthesised paths are updated to reflect the new location in the same step as the move
  when reading a tree reveals an error in its leaf text
    then the tree's leaf text is corrected before writing the test
    and the test mirrors the corrected text rather than replicating the error
  when an expected-red test passes incidentally
    then break the implementation intentionally
    and observe the test failing
    then fix the implementation, observe the test passing, and move on
  when a failing higher-layer test surfaces inner behaviour that requires new code
    then the failing higher-layer test is run and its failure is read to identify the next layer down to descend into
    and a tree for the inner unit is added at its native ground layer before code is written
    and the inner unit's own failing test is written before any implementation lands
    and implementation is not written off the journey/functional failure alone — only once the failing ground-level test exists beneath it
    and the higher-layer test passing is not treated as sufficient coverage for the inner unit
    and overlap between the inner tree's coverage and the higher-layer test is intentional, not waste
  when descending the layers from a failing higher-layer test
    then each layer's failing test guides the next failing test one layer down — Journey to System to Component to Adapter to Use-case to Domain or Port
    and descent continues to the lowest layer the behaviour reaches
    and descent never stops at a higher layer because the behaviour appears already covered there
    and coverage at a higher layer never justifies skipping a test at a lower layer
    and every layer the behaviour touches ends with its own complete coverage, written down to the lowest level
  when the lowest-layer failing test for the behaviour is made to pass
    then the layers fold back up — each higher-layer test passes in turn as the layers beneath it are satisfied, up to the Journey
    and a higher-layer test still failing means a layer beneath it lacks coverage, so another lower failing test is written before retrying upward
  when all trees for a slice have passing tests
    then run mutation testing against Domain and Use-case layers as final validation
    and suggest the user runs sync
  if no tree covers the behaviour
    then suggest the user runs change first
  when starting to implement a tree
    then the covering tree is identified and stated explicitly before any test is written
    and an incomplete-seeming tree is noted but implementation proceeds with what's there
  when writing a Domain test
    then the pure rule is tested with no collaborators
    and the test calls functions directly, asserting on returned data
  when writing an Adapter test for a driving adapter, and the protocol translation is non-trivial
    then a driving-adapter test is written with the use-case mocked
    and the test asserts on protocol-to-input translation — routing, deserialization, auth extraction, error-code shaping
  when all tests are green after an inner cycle
    then only the code just changed is refactored, not more broadly
    and duplication is treated as a hint to watch, not a command to immediately extract
  when a test fails unexpectedly during the cycle
    then an unrelated failure is fixed first before continuing
    and a related failure is fixed as part of continuing the cycle
    and a missing or wrong test is corrected before continuing
```

## pre-task-hook

```
pre-task-hook (src: hooks/session-start.sh; system: test/pre-task-hook.bats; journey: test/journey/docker-entrypoint.sh)
  when a session starts
    then MENTAL_MODEL.md contents are displayed
    and TEST_TREES.md contents are displayed
    and the agent is directed to use the mental model's existing concepts, vocabulary, and decisions rather than inventing parallel ones
    and the agent is directed to preserve the mental model's invariants, surfacing conflict when a task appears to require breaking one rather than routing around it
    and the agent is directed to flag the mental model as wrong, incomplete, or misleading rather than silently reshaping it through code
    and the agent is directed to treat test trees as the authoritative behaviour contract
    and the agent is directed to describe each level's observable behaviour at its interface — inputs, outputs, and side-effects — not the implementation inside it
    and the agent is directed that every layer owns complete coverage of its own behaviour — a higher-layer test, green or red, never excuses a missing lower-layer test, and overlap across layers is intentional
    and the agent is directed that journey and functional coverage is never coverage of the layers beneath — implementation waits for a ground-level failing test under the journey/functional failure
    and the agent is directed to descend outside-in through every layer the behaviour touches — running each failing test to guide the next one layer down, to the lowest applicable level — never stopping because the behaviour appears already covered at a higher layer, then folding back up as the layers beneath pass
    and the agent is directed to decide obvious questions itself rather than asking the user — consulting these rules and the mental model first, then its own best judgment from the code in front of it, escalating to the user only a consequential, genuinely under-determined choice that neither resolves
    and the agent is directed to apply the same ladder to anything it would flag, caveat, or surface — fixing it where these rules or the mental model direct, else using its judgment, else staying silent rather than reporting it
    and the agent is directed to eagerly use the listed skills to fulfil operator requests where applicable
    and the agent is directed to use the change skill for any behaviour change, before any code is discussed or written
    and the agent is directed to use the tdd skill when implementing behaviour, writing code, or writing tests
    and the agent is directed to use the sync skill when asked about drift, gaps, staleness, or completeness
    and the agent is directed to use the setup skill when no test framework is configured or TEST_TREES.md is absent
    and the agent is directed to use the workflow skill for the full arc from idea to verified working software
```

## post-task-hook

```
post-task-hook (src: hooks/stop-drift-check.sh; system: test/post-task-hook.bats; journey: test/journey/docker-entrypoint.sh)
  when Claude stops after a response that does not end with a question
    then a mental-model nudge prompts consideration of whether the task revealed any knowledge not already described in documentation, tests, and code, defaulting to no change
      when a change is warranted
        then the edit declares which of the seven sections it belongs to
        and an edit fitting no section is not added to the mental model
        and tightening an existing line is preferred over adding a new one
        and statements describe what is true, not what to avoid
        and when the target section is at its cap, an existing item is displaced or merged rather than appended
    and a test-trees nudge prompts detection of drift between trees and implementation
    and a claude-md nudge prompts detection of drift between CLAUDE.md content and reality
    and a readme nudge prompts detection of readme staleness against what the project is, how consumers install it, configure it, and use it
  when Claude stops after a response that ends with a question
    then the hook injects a question-stop prompt in place of the drift nudges
    and the prompt directs the agent to check whether the rules, mental model, and test trees already determine the answer
    and the prompt directs the agent to decide and act on that answer rather than ask the user when they determine it
    and the prompt directs the agent to put the question to the user only when the answer is genuinely under-determined by all of them
  when stop_hook_active is true
    then the hook exits silently to prevent infinite loops
  when no nudge reports anything
    then Claude replies with 0
  if MENTAL_MODEL.md is missing at the project root
    then the mental-model nudge instead directs creation of MENTAL_MODEL.md with the seven named H2 sections in order
  if README.md is missing at the project root
    then the readme nudge instead directs creation of README.md describing what the project is, how consumers install it, configure it, and use it
  if MENTAL_MODEL.md and README.md exist at the project root but the hook runs from a subdirectory
    then no missing-file nudge is emitted, because presence is judged at the project root rather than the hook's working directory
```

## post-update-hook

```
post-update-hook (src: hooks/post-update-check.sh; system: test/post-update-hook.bats; journey: test/journey/docker-entrypoint.sh)
  when MENTAL_MODEL.md is edited via a tool call
    then the validator runs against the post-edit content
    and its findings are surfaced to Claude's next response via additional context
  when a file other than MENTAL_MODEL.md is edited
    then the validator does not run
  when contree is installed
    then hooks.json wires post-update-check.sh to the PostToolUse hook event
```

## mental-model-validator

```
mental-model-validator (src: hooks/validate-mental-model.sh; system: test/mental-model-validator.bats; journey: test/journey/docker-entrypoint.sh)
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
setup-generates-trees (src: skills/setup/SKILL.md; system: test/setup-generates-trees.bats; journey: test/journey/docker-entrypoint.sh)
  when setup is run on an existing project
    then existing test config is detected and merged into, not overwritten
    and tree reporters are configured for both local dev and CI (dual reporters)
    and the six test layers (Domain, Use-case, Component, Adapter, System, Journey) are configured as separate commands
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
  when the project needs external services for Adapter, System, or Journey tests
    then those layers run in Docker
    and test artefacts are torn down afterwards
    and secrets are passed via environment variables
  when Component tests run
    then they run in-process with an in-memory database and stubbed outbound HTTP, needing no external services
```

## setup-installs-architectural-linter

```
setup-installs-architectural-linter (src: skills/setup/SKILL.md; system: test/setup-installs-architectural-linter.bats; journey: test/journey/docker-entrypoint.sh)
  when setup is run
    then a hex-boundary linter is installed and configured
    and the linter enforces that domain has no I/O
    and the linter enforces that use-cases depend on ports, not concrete adapters
    and the linter enforces no circular dependencies
    and CI is wired to run the linter so boundary violations fail the build
  if the project's language has no first-party contree linter template
    then the language-native equivalent tool is named and the rules to enforce are stated
    and the limitation — the user wires the rules themselves — is communicated honestly
```

## change-writes-trees

```
change-writes-trees (src: skills/change/SKILL.md; system: test/change-writes-trees.bats; journey: test/journey/docker-entrypoint.sh)
  when a behaviour change is needed
    then the change is discussed with the user before modifying trees
    and EARS patterns are chosen to match each requirement's nature
    and every then clause asserts something the when clause does not already imply
    and Journey → System → inner-layer decomposition is planned, one tree per behavioural unit
    and every tree's paths map verbatim to a describe/it hierarchy in one test file
  when a Journey, System, or Adapter tree is written
    then paths use the consumer's vocabulary, not implementation internals
    and paths describe principles, not enumerated cases
  when a Domain, Use-case, or Port-contract tree is written
    then top-level nodes name the unit's exported functions, methods, or port operations
    and each path corresponds to an observable branch in the unit
  when a tree is written
    then its coverage is named in parenthesised semicolon-separated pairs at the end of the tree-name line, labelled src / domain / use-case / adapter / component / system / journey
    and gaps are declared explicitly — "none" for expected-but-uncovered categories, omission for not-applicable ones
    and if naming a (sub)tree's paths reveals an awkward shape, the tree or implementation is reshaped rather than the paths being stripped
  when planning a change to an area that already has a tree and implementation
    then the current tree and its paths are compared against the actual tests and file locations before drafting the change
    and any pre-existing tree-code drift in that area is reconciled as part of the change so the new tree is coherent with post-change reality
  when a tree path's then clause would reference another leaf to convey its meaning
    then the path is rewritten to state its assertion inline
    and phrases like "see above", "as before", or "the existing X branch holds" are not used
  when the user describes new behaviour as "the same as" or "just like" an existing tree's behaviour
    then the existing tree's paths are duplicated under the new subject in full rather than cross-referenced
    if duplication reveals the two subjects share a single concept
      then they are collapsed under one tree named for the shared concept
      and the implementation is made generic to serve both
  when modifying existing behaviour
    then only affected paths are changed
  when removing a capability
    then the tree is removed after user confirmation
  when trees are complete
    then they are presented to the user for alignment
    and the user is suggested to run sync
  when a tree is named
    then its first line is exactly `<Layer>: <Subject>`
    and the layer prefix lets readers and sync detect duplication across trees that share a subject at different layers
  when a when-trigger can only occur as a consequence of a prior then-outcome
    then it is nested as a child of that outcome, not written as a sibling
```

## change-decomposes-across-layers

```
change-decomposes-across-layers (src: skills/change/SKILL.md; system: test/change-decomposes-across-layers.bats; journey: test/journey/docker-entrypoint.sh)
  when a behaviour change is planned
    then the outermost tree is captured — a Journey tree for a new user arc, or a System tree for a capability under an existing journey
    and that outermost tree is the only tree written up front — System and inner-layer trees are added only as a failing journey/functional test reveals the need for them
    and trees are named for the subject with observable behaviour at their layer
    and every tree reifies exactly one test file
  when decomposing a capability across the test layers
    then the layers pair two orientations across two realism tiers — behaviour-oriented (Use-case, Journey) and system-oriented (Component, System)
    and Use-case is to Component as Journey is to System — the cheap tier doubles what it can, the real tier integrates everything affordable
    and Use-case and Component are always written and carry exhaustive coverage; System and Journey are selective, validating the same surfaces with real everything
  when an inner-layer tree is added
    then it exists because the failing journey/functional test at max realism cannot be satisfied without it
    and inner-layer trees are never designed up front from speculation about decomposition
  when a side effect is identified
    then it becomes an outbound port named for capability, not technology
    and the port ships in two flavours: an in-memory adapter and a real adapter
    and a shared contract suite is written for the port
    and both adapters must pass the shared suite
  if a capability is a pure library with no driving adapter, use-case, or driven port
    then a System tree is written only when a cross-function invariant is observable across the library's functions
    and otherwise System is omitted and the omission is documented rather than left as an untree'd test file
  when a Domain, Use-case, Driving-adapter, or Driven-adapter tree is considered for a unit
    then it is written only if that unit has its own substantive behaviour — rules, non-trivial orchestration, non-trivial translation, or adapter-specific behaviour beyond its contract
    and a unit that only delegates or trivially forwards does not earn its own tree
  when an app-level invariant applies across slices rather than to one
    then it is captured as a cross-cutting System tree named for the policy, not folded into a single slice's tree
  when a System test is written for a capability that also has a Use-case in-memory twin
    then the System test wires the real driven adapter, never the in-memory twin
```

## sync-audits-and-resolves

```
sync-audits-and-resolves (src: skills/sync/SKILL.md; system: test/sync-audits-and-resolves.bats; journey: test/journey/docker-entrypoint.sh)
  then drift is never resolved unilaterally — every case is presented to the user for a decision before any edit
  if the project's test trees do not exist or are empty
    then sync stops and suggests running setup first
  when sync is run
    then every when/then path is checked for implementation and tests
    and each test file's describe/it hierarchy is parsed and compared to its tree
    and each tree's labelled parenthesised paths are verified against the filesystem per category
    and every "none" value is surfaced as an explicit gap for the user to resolve
    and drift between trees and implementation is identified
  when implementation exists without a tree
    then it is discussed with the user — may need a tree or may need removing
  when a tree exists without implementation
    then it is flagged as a gap to implement
  when code is reachable only through higher-layer tests with no tree at its native layer
    then it is flagged as coverage-by-proxy drift
    and the proposed resolution is a new tree at the unit's native layer plus its own failing tests
    and removal of the higher-layer test is never proposed as the resolution
  when a tree's named path does not exist on disk
    then it is flagged as drift
  when a test file's describe/it hierarchy disagrees with its tree
    then both are presented to the user for resolution
    and sync does not pick a side
  when stale trees or dead paths are found
    then they are discussed with the user before removal
  when gaps are identified
    then the user is suggested to run tdd to implement them
  when the project is in sync
    then the user is suggested to run second-opinion for an independent review of the completed work
  when a Domain, Use-case, or Port-contract tree is checked
    then every observable branch in the unit's code corresponds to a tree path, and every tree path corresponds to a branch
  when a test exists for a tree path but does not pass
    then the implementation is assumed wrong by default unless evidence says otherwise
    and fixing it is treated as part of sync, not deferred to the user
    and sync is not complete while any test is red
  when a slice has inner trees but no System tree above them
    then a System tree is written for the slice, or the pure-library exception is confirmed and the omission documented
    and a System tree is never invented silently
  when all gaps are implemented and all tests pass
    then mutation testing is run against Domain and Use-case as final validation, if configured
```

## workflow-runs-end-to-end

```
workflow-runs-end-to-end (src: skills/workflow/SKILL.md; system: test/workflow-runs-end-to-end.bats; journey: test/journey/docker-entrypoint.sh)
  when workflow is run with an idea
    then change, sync, and tdd run in sequence without pausing
  when change completes
    then sync runs immediately
  when sync identifies gaps
    then tdd implements each gap immediately
  when all gaps are implemented
    then all test trees have passing tests
  when the work is synced and implemented
    then second-opinion reviews the completed work with an independent model
  when tdd closes all gaps
    then mutation testing runs at the end of the tdd phase
  when second-opinion finds drift or gaps
    then they are routed back through change, sync, or tdd
```

## skill-discoverability

```
skill-discoverability (src: hooks/session-start.sh; system: test/skill-discoverability.bats; journey: test/journey/docker-entrypoint.sh)
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
composable-testing (src: skills/setup/SKILL.md, skills/change/SKILL.md; system: test/composable-testing.bats; journey: test/journey/docker-entrypoint.sh)
  when a project uses contree
    then Domain tests are colocated with source (*.domain.test.*)
    and Use-case tests are colocated with the use-case (*.use-case.test.*)
    and Adapter tests are colocated with the adapter — driving or driven (*.adapter.test.*)
    and Component tests live under test/component/ (*.component.test.*)
    and System tests live under test/system/ (*.system.test.*)
    and Journey tests live under test/journey/ (*.journey.test.*)
    and Component tests wire real driving and driven adapters for one capability, doubling externals only at the edge — an in-memory database and stubbed outbound HTTP
    and System tests wire real driven adapters at the highest tolerable realism by default
    and Journey tests wire real driving and driven adapters across the multi-capability arc at max realism
    and exhaustive single-capability breadth lives at the Component and Use-case layers
    and every layer produces tree-shaped output
    and mutation testing validates quality at the Domain and Use-case layers
```

## rules-loading

```
rules-loading (src: hooks/session-start.sh; system: test/rules-loading.bats; journey: test/journey/docker-entrypoint.sh)
  when a session starts
    then the rules list is shown
    and not repeated on every response
    and hooks.json wires session-start.sh to the SessionStart hook event
```

## self-care-20-20-20

```
self-care-20-20-20 (src: hooks/self-care-20-20-20.sh; system: test/self-care.bats; journey: test/journey/docker-entrypoint.sh)
  when the UserPromptSubmit hook fires in any session
    then hooks.json wires it to hooks/self-care-20-20-20.sh
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

## dual-harness-compatibility

```
dual-harness-compatibility (src: .claude-plugin/plugin.json, .codex-plugin/plugin.json, hooks/hooks.json; system: test/dual-harness-compatibility.bats; journey: test/journey/docker-entrypoint.sh)
  when contree is installed under either Claude Code or Codex
    then a manifest exists at .claude-plugin/plugin.json
    and a manifest exists at .codex-plugin/plugin.json declaring skills as ./skills/ and hooks as ./hooks/hooks.json
    and both manifests carry the same name and version
    and .claude-plugin/plugin.json declares a name of "contree", a version, and a description
    and one hooks/hooks.json is shared by both harnesses
  when a hook fires
    then hooks.json invokes its script via $CLAUDE_PLUGIN_ROOT — the env var both harnesses set
  when an Edit, Write, or MultiEdit tool call completes
    then the PostToolUse matcher fires
  when the Stop hook fires
    then hooks.json wires it to hooks/stop-drift-check.sh
  when Codex is the harness
    then Codex itself aliases apply_patch to match this matcher — Codex-side behaviour, not contree-configured or testable from this repo
```

## diff-images-the-change

```
diff-images-the-change (src: skills/diff-for-humans/SKILL.md; system: test/diff-images-the-change.bats; journey: test/journey/docker-entrypoint.sh)
  when the diff-for-humans skill is invoked
    then it determines the change to depict from any natural-language indication the user gave
    and absent a clear indication it depicts the last non-trivial, naturally grouped changes — not a single commit, since trunk-sync commits continuously, and not only the working tree
    and the change it gathers includes new files not yet tracked by git
    and it generates an image representing that change using OpenAI's gpt-image-2 model via the images generations API
    and it chooses what the image depicts from the nature of the change, its important details, and its intended audience
    and it foregrounds the technical substance the change touches — contracts, data and databases, behaviour, and test trees — as concrete technical elements rather than only an abstract metaphor
    and it saves the returned image as a .png file
    and it surfaces those choices to the user for review
  when there are no non-trivial changes to depict
    then it says so and stops without calling the API
  if the gpt-image-2 request fails
    then the failure is surfaced as an error and no image is fabricated
```

## second-opinion-reviews-completed-work

```
second-opinion-reviews-completed-work (src: skills/second-opinion/SKILL.md; system: test/second-opinion-reviews-completed-work.bats; journey: test/journey/docker-entrypoint.sh)
  when the second-opinion skill is invoked
    then it determines the work to review from any natural-language indication the user gave
    and absent a clear indication it reviews the last non-trivial, naturally grouped changes — not a single commit, since trunk-sync commits continuously, and not only the working tree
    and the work it gathers includes new files not yet tracked by git
    and it reads the test trees as the contract the work must satisfy
    and it sends the change and the test trees to Z.AI's GLM 5.2 via the chat completions API authenticated with ZAI_API_KEY
    and it surfaces GLM 5.2's review to the user attributed to GLM 5.2
  when there are no non-trivial changes to review
    then it says so and stops without calling the API
  if the review request fails — missing ZAI_API_KEY, an API error, a non-2xx response, or empty content
    then the failure is surfaced as an error and no review is fabricated
```

## validate-skill-frontmatter

```
validate-skill-frontmatter (src: scripts/validate-skill-frontmatter.sh; system: test/validate-skill-frontmatter.bats)
  when every skills/*/SKILL.md has non-empty frontmatter name and description
    then the validator exits 0
    and this holds for contree's own real skills/ directory, not just synthetic fixtures
  when the skills directory has no SKILL.md files
    then the validator exits 0
  if a SKILL.md's frontmatter name is missing
    then the validator exits non-zero and names the offending file
  if a SKILL.md's frontmatter description is empty
    then the validator exits non-zero and names the offending file
  if a SKILL.md has no frontmatter at all
    then the validator exits non-zero
  if a SKILL.md's frontmatter has no closing marker
    then the validator exits non-zero
  if the skills directory does not exist
    then the validator exits non-zero
  if no argument is given
    then the validator exits non-zero
```

## website-explains-contree

```
website-explains-contree (src: website/index.html; system: test/website-explains-contree.bats)
  when a visitor loads the contree website
    then the page bridges from test-first practice to test trees as living requirements
    and the page explains the layered testing architecture from Journey down to Domain
    and the page walks the skill workflow — setup, change, sync, tdd, second-opinion
    and the page explains the Claude Code hook mechanics — the stdout, stderr-exit-2, and additionalContext injection channels, and the Stop-hook control flow
    and the page requires no build step
```

Note: `.github/workflows/pages.yml`, the deploy mechanism that publishes this page, lives outside `contree/` as monorepo-level shared infrastructure (one workflow staging every plugin's `website/` into its own subdirectory) and is documented in the repo-root `CLAUDE.md` rather than tree'd here — contree's own trees and tests are scoped to files under `contree/`, matching every other tree's `$PROJECT_ROOT`-relative paths.

## Cross-Functional Requirements

- Supported languages: JS/TS (Node, Bun, React, React Native), Elixir (Phoenix, Jido), Go. Setup refuses other languages and names the supported set.
- Mutation testing is omitted for Elixir — no mature tool exists. Users are pointed at property-based testing with StreamData as a substitute.
