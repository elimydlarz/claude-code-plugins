## test-trees-as-requirements

```
Unit: test-trees-as-requirements (unit: test/test-trees-as-requirements.bats)
  when a project uses contree
    then CLAUDE.md identifies TEST_TREES.md as the definition of functional and cross-functional requirements
    and TEST_TREES.md defines functional requirements using EARS syntax
    and each behavioural unit has its own tree in TEST_TREES.md
    and trees are flat subsections — not grouped by kind or layer
    and every tree reifies exactly one test file
    and every test file reifies exactly one tree
    and every tree names its coverage in parenthesised labelled pairs on the tree-name line, covering the categories src, unit, integration, component, journey
    and gaps are declared explicitly — "none" for expected-but-uncovered categories, omission for not-applicable ones
    and the EARS rule is embedded where trees are written
  when a behaviour change is needed
    then the tree must exist before implementation starts
  when implementation reveals new understanding
    then the tree is updated to reflect reality
```

## bootstrap-test-trees

```
Unit: bootstrap-test-trees (src: skills/bootstrap-test-trees/SKILL.md; unit: test/bootstrap-test-trees.bats)
  when an operator asks to bootstrap test trees for an existing project
    then the skill runs setup-mental-model and setup-test-trees as focused prerequisite phases
    and it proves both project-local steering hooks are active before implementing tests
    and a second wave of subagents implements non-overlapping test trees as tests whose hierarchy mirrors each tree verbatim
    and every tree maps to exactly one uncommented test file
    and the coding agent reconciles the test implementations and runs the normal and functional test commands
  when an operator asks to bootstrap test trees for a new project
    then the skill runs setup-mental-model and setup-test-trees to create their empty homes and project-local steering hooks
    and it leaves behaviour trees and tests to be pulled into existence by the first requested capability
  if bootstrapped tests expose behaviour that disagrees with the operator's intended contract
    then the disagreement is left visible and routed through change or tdd rather than weakened in the trees or tests
```

## setup-mental-model

```
Unit: setup-mental-model (src: skills/setup-mental-model/SKILL.md; unit: test/setup-mental-model.bats)
  when an operator asks to set up a mental model for an existing project
    then the skill agrees the evidence and non-overlapping discovery areas with the operator
    and discovery subagents report domain identity, world-to-code mapping, language, boundaries, invariants, rationale, temporal knowledge, and contradictions from inspected files
    and the coding agent reconciles the evidence with the operator into exactly the seven mental-model sections
    and unsupported claims and consequential disagreements remain visible rather than being silently invented or resolved
    and project SessionStart hooks load the mental model before coding agents work
    and project Stop hooks ask the coding agent to reconcile newly learned domain knowledge before it finishes
    and the skill proves both hooks through actual coding-agent turns before reporting completion
  when an operator asks to set up a mental model for a new project
    then the skill creates the seven-section mental-model home without inventing domain knowledge
    and it installs and proves the same project-local steering hooks
```

## setup-test-trees

```
Unit: setup-test-trees (src: skills/setup-test-trees/SKILL.md; unit: test/setup-test-trees.bats)
  when an operator asks to set up test trees for an existing project
    then the skill explains the behavioural evidence it will gather and agrees complete non-overlapping scope with the operator
    and discovery subagents inspect every area for observable behaviour, existing tests, public seams, errors, side effects, and contradictions
    and the coding agent reconciles the evidence with the operator through change into layered EARS trees with honest coverage
    and every discovered behaviour is expressed at its consumer-visible seam without inventing unsupported behaviour
    and project SessionStart hooks load TEST_TREES.md and the tree-writing rules before coding agents work
    and project Stop hooks ask the coding agent to reconcile drift between trees, tests, and implementation before it finishes
    and the skill proves both hooks through actual coding-agent turns before reporting completion
  when an operator asks to set up test trees for a new project
    then the skill creates an empty test-tree home without inventing behaviour
    and it installs and proves the same project-local steering hooks
```

## outside-in-tdd

```
Unit: outside-in-tdd (src: skills/tdd/SKILL.md; unit: test/outside-in-tdd.bats; journey: test/journey/docker-entrypoint.sh)
  when TDD starts
    then the current test tree is read before tests or implementation
    and one observable behaviour is selected
    and development proceeds outside-in from that behaviour's consumer
  when choosing a test kind
    then Journey, Component, Integration, and Unit are defined in the same concise terms as the session rules
    and the test kind describes the current test rather than a predetermined implementation order
  when setting up mocks for a Unit test
    then the agent first identifies the observable result and intentional side effects that the test asserts
    and treats other dependency interactions as implementation details of how the subject currently produces that behaviour
    when an intentional side effect is part of the behaviour under test
      then the mock records the interaction
      and the test asserts that it is called correctly with meaningful arguments
    when a dependency interaction is an implementation detail
      then the mock responds only to the exact realistic invocation and arguments
      and the interaction is not asserted
      and the test asserts the subject's observable result, so an incorrect interaction cannot make the test pass
  when implementing the selected behaviour
    then the exact process is write a test, observe RED, implement to GREEN, observe too much branching in the test or tree during REFACTOR, imagine a unit that encapsulates some of that branching, create its mock and throwing stub, make the consumer call it, and TDD the new unit by returning to the first step
    and only one test is written and run at a time
    and only enough real behaviour to pass that test is implemented
  when the passing test or its tree contains too much branching under different conditions
    then a unit that can encapsulate that branching is imagined
    and the unit is not designed before the branching is observed
  when the imagined unit is mocked
    then the consumer tests are simplified so they pass only when the mock is consumed correctly
    and the mock visibly names why it exists
    and a stub implementation of the unit throws NotImplemented
    and the consumer implementation calls the unit
    and the consumer tests pass through the mock while running the code fails at the throwing stub
  when the mocked unit becomes the TDD subject
    then the passing mock and throwing stub signal that the new unit must be TDDed
    and its own tree describes the behaviour its consumer requires before its first test
    and the TDD process returns to step 1 with that unit as the new subject
    and its implementation replaces the throwing stub as its tests are made green
  when a test is expected to be red
    then the failure is observed before implementation
    and an incidentally passing test is shown to fail before it is trusted
  when a test is green
    then refactoring is limited to the behaviour just implemented
    and duplication is treated as a hint while branching under different conditions is the reason to imagine a unit
  when tests and source files are created, moved, or renamed
    then the tree's labelled coverage paths are updated immediately
    and a covered "none" value is replaced with the created path
  when TDD is complete
    then every affected tree path passes
    and every mocked unit has its own tree and test file
    and test hierarchies mirror their trees verbatim
    and no NotImplemented stub remains
```

## pre-task-hook

```
Unit: pre-task-hook (src: hooks/session-start.sh; unit: test/pre-task-hook.bats; journey: test/journey/docker-entrypoint.sh)
  when a session starts
    then MENTAL_MODEL.md contents are displayed
    and TEST_TREES.md contents are displayed
    and the agent is directed to use the mental model's existing concepts, vocabulary, and decisions rather than inventing parallel ones
    and the agent is directed to preserve the mental model's invariants, surfacing conflict when a task appears to require breaking one rather than routing around it
    and the agent is directed to flag the mental model as wrong, incomplete, or misleading rather than silently reshaping it through code
    and the agent is directed that trees are the contract — every observable behaviour and side effect belongs in TEST_TREES.md, every tree maps to one test file, and every test file's describe/it hierarchy mirrors its tree verbatim
    and the agent is directed to describe each level's observable behaviour at its interface — inputs, outputs, and side-effects — not the implementation inside it
    and the agent is directed that Journey, Component, Integration, and Unit are the test kinds
    and the agent is directed to work outside-in and consumer-driven from the behaviour in the current tree
    and the agent is directed to write a test, observe RED, implement GREEN, then notice too much branching in the test or tree during REFACTOR
    and the agent is directed to extract some branching into a new unit with a mock and a stub that throws NotImplemented
    and the agent is directed that the mock makes consumer tests pass while the stub makes running code fail loudly, signalling that the TDD process repeats from step 1 for the new unit
    and the agent is directed to decide obvious questions itself rather than asking the user — consulting these rules and the mental model first, then its own best judgment from the code in front of it, escalating to the user only a consequential, genuinely under-determined choice that neither resolves
    and the agent is directed to apply the same ladder to anything it would flag, caveat, or surface — fixing it where these rules or the mental model direct, else using its judgment, else staying silent rather than reporting it
    and the agent is directed to use Contree skills as directed by skill frontmatter
    and the agent is shown every focused setup skill alongside change, tdd, sync, setup, and change-without-me
```

## post-task-hook

```
Unit: post-task-hook (src: hooks/stop-drift-check.sh; unit: test/post-task-hook.bats; journey: test/journey/docker-entrypoint.sh)
  when Claude stops after a response
    then a mental-model nudge prompts consideration of whether the task revealed any knowledge not already described in documentation, tests, and code, defaulting to no change
      and directs creation of MENTAL_MODEL.md with the seven named H2 sections in order when it is missing at the project root
      when a change is warranted
        then the edit declares which of the seven sections it belongs to
        and an edit fitting no section is not added to the mental model
        and tightening an existing line is preferred over adding a new one
        and statements describe what is true, not what to avoid
        and when the target section is at its cap, an existing item is displaced or merged rather than appended
    and a test-trees nudge prompts detection of drift between trees and implementation
    and a claude-md nudge prompts detection of drift between CLAUDE.md content and reality
    and a readme nudge prompts detection of readme staleness against what the project is, how consumers install it, configure it, and use it
      and directs creation of README.md with those consumer-facing details when it is missing at the project root
  when stop_hook_active is true
    then the hook exits silently to prevent infinite loops
  when no nudge reports anything
    then Claude replies with 0
  if MENTAL_MODEL.md and README.md exist at the project root but the hook runs from a subdirectory
    then no missing-file nudge is emitted, because presence is judged at the project root rather than the hook's working directory
  when Codex runs the Stop hook without CLAUDE_PROJECT_DIR
    then the hook uses the current working directory as the project root
    and emits the normal drift prompt instead of failing
```

## setup-test-feedback

```
Unit: setup-test-feedback (src: skills/setup-test-feedback/SKILL.md; unit: test/setup-test-feedback.bats)
  when an operator asks to set up test feedback
    then the skill inspects the existing project and agrees the framework choice and command mapping with the operator before changing files
    and it merges existing test configuration instead of replacing it
    and it configures tree-shaped normal and journey test output where the ecosystem supports it
    and the normal command runs Unit, Integration, and Component tests while the journey command separately runs Journey tests
    and a native test-changed command plus synchronous project save hooks give coding agents the impacted normal-test result after each file edit
    and it runs both test commands and verifies the test-changed baseline and impact selection before reporting completion
  if a configured test command or project hook fails verification
    then the skill fixes the configuration and reruns verification until the feedback path works
  when tests need external services
    then the relevant command owns a self-contained Docker lifecycle and always tears its test artefacts down
```

## setup-linter

```
Unit: setup-linter (src: skills/setup-linter/SKILL.md; unit: test/setup-linter.bats)
  when an operator asks to set up code linting
    then the skill inspects the ecosystem and existing configuration and agrees the strong conventional rules with the operator
    and it installs and merges the conventional linter without replacing project-owned rules
    and it creates a native lint command and CI gate
    and synchronous project save hooks run the linter's autofix command from the project root before the coding agent continues
    and the skill runs autofix and lint across the existing project before reporting completion
  if lint violations remain after automatic fixes
    then the skill fixes the remaining violations and reruns lint until it passes
  if a save-time autofix cannot complete
    then the project hook reports the complete linter output and fails visibly
```

## setup-architecture-linter

```
Unit: setup-architecture-linter (src: skills/setup-architecture-linter/SKILL.md; unit: test/setup-architecture-linter.bats)
  when an operator asks to set up architecture linting
    then the skill maps the project's actual domain, use-case, port, adapter, and composition-root locations with the operator
    and it installs and configures rules that keep domain code pure, dependencies pointing inward, adapters reachable only from the composition root, and dependency cycles absent
    and it creates a native architecture command, combines it with the project lint command, and adds the combined gate to CI
    and project Stop hooks run every architecture rule from the project root before the coding agent finishes
    and the skill runs every architecture rule before reporting completion
  if the project's ecosystem cannot enforce every required boundary
    then the skill fails visibly without claiming architecture feedback is configured
  if architecture violations are found during setup
    then the skill invokes fix-architecture with the complete violations
  if the architecture linter cannot run from a project Stop hook
    then the hook reports the execution error and fails visibly
  when the project Stop hook receives its own follow-up Stop task
    then it exits silently without running architecture lint again
```

## fix-architecture

```
Unit: fix-architecture (src: skills/fix-architecture/SKILL.md; unit: test/fix-architecture.bats)
  when an operator asks to fix architecture violations
    then the skill runs the architecture linter and partitions the reported violations into non-overlapping work for subagents
    and subagents fix violations without disabling rules, weakening boundaries, or adding exemptions
    and the coding agent reconciles their changes and reruns every architecture rule
    and repeated violations are repartitioned and fixed until architecture lint passes
  if a violation conflicts with the operator's intended architecture
    then the skill resolves the architecture and mental-model decision with the operator before changing the enforced boundary
```

## setup-mutation-testing

```
Unit: setup-mutation-testing (src: skills/setup-mutation-testing/SKILL.md; unit: test/setup-mutation-testing.bats)
  when an operator asks to set up mutation testing
    then the skill inspects the source and test layout and agrees the mutation scope and useful feedback threshold with the operator
    and it configures the ecosystem's mutation tool to mutate production source while explicitly excluding every colocated test pattern
    and mutation test runners select only Unit tests when the framework supports test selection
    and incremental mode and a native mutation command provide the fastest available repeat feedback
    and project Stop hooks run incremental mutation feedback only when relevant Unit subjects or tests changed
    and the hook preserves complete surviving-mutant output and fails visibly when the agreed threshold is missed
    and the skill runs mutation testing before reporting completion
  if surviving mutants keep the agreed threshold from passing
    then the skill strengthens the responsible Unit tests and reruns only the affected mutation scope until it passes
```

## setup-prepares-project

```
Unit: setup-prepares-project (src: skills/setup/SKILL.md; unit: test/setup-prepares-project.bats; journey: test/journey/docker-entrypoint.sh)
  when an operator asks for comprehensive Contree setup
    then setup inspects the project and presents a dynamic setup workflow shaped by the steering that is missing
    and setup engages the operator at each consequential framework, architecture, behavioural-scope, and mutation-threshold decision
    and setup orchestrates setup-test-feedback, setup-linter, setup-architecture-linter, bootstrap-test-trees, and setup-mutation-testing while bootstrap composes setup-mental-model and setup-test-trees
    and each completed setup phase expands project-local hooks so later coding agents receive progressively richer steering while they work
    and setup uses subagents for independent setup work that can safely run in parallel and reconciles their results
    and setup keeps focused-skill orchestration in the coordinator instead of delegating an entire focused skill to an unattended background agent
    and setup waits for every selected phase and its subagents to finish before starting a dependent phase or reporting completion
    and setup proves each phase from its required commands and retained artifacts rather than accepting a subagent summary as proof
    and setup proves bootstrap retained layered EARS trees with exactly one test file per tree before mutation setup begins
    and setup runs every configured feedback command, verifies impacted tests through synchronous project save hooks after file edits, and fixes failures before reporting the project prepared
    and setup reports the installed commands, automatic hooks, test-tree coverage, and mutation result to the operator
  if any specialised setup skill cannot establish its feedback loop
    then setup fails visibly and does not claim that the project is prepared
```

## change-writes-trees

```
Unit: change-writes-trees (src: skills/change/SKILL.md; unit: test/change-writes-trees.bats; journey: test/journey/docker-entrypoint.sh)
  when a behaviour change is needed
    then the change is discussed with the user before modifying trees
    and EARS patterns are chosen to match each requirement's nature
    and every then clause asserts something the when clause does not already imply
    and the test kind is chosen from Journey, Component, Integration, and Unit according to the observable scope under test
    and every tree's paths map verbatim to a describe/it hierarchy in one test file
  when a Journey or Component tree is written
    then paths use the consumer's vocabulary, not implementation internals
    and paths describe principles, not enumerated cases
  when an Integration tree is written
    then the tree names the highest-level subject and the other subjects whose real collaboration is being verified
    and every dependency outside those integrated subjects is mocked
  when a Unit tree is written
    then the tree describes what the consumer needs to observe from one public surface on one subject
    and pure functions are still described from the caller's need to observe their result or error
  when a tree is written
    then its coverage is named in parenthesised semicolon-separated pairs at the end of the tree-name line, labelled src / unit / integration / component / journey
    and gaps are declared explicitly — "none" for expected-but-uncovered categories, omission for not-applicable ones
    and if naming a tree's paths reveals a mismatch between the consumer need and the file boundaries, the tree or implementation is adjusted until the mapping is honest
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

## change-chooses-test-kinds

```
Unit: change-chooses-test-kinds (src: skills/change/SKILL.md; unit: test/change-chooses-test-kinds.bats; journey: test/journey/docker-entrypoint.sh)
  when a behaviour change is planned
    then the outermost tree is captured — a Journey tree for a broad user arc, or a Component tree for one whole-app capability
    and that outermost tree is the only tree written up front — Integration and Unit trees are added only as a failing consumer test reveals the need for them
    and trees are named for the highest-level subject with observable behaviour at their test kind
    and every tree reifies exactly one test file
  when choosing a test kind
    then Journey covers a broad production-like user arc across capabilities, replacing external services with test doubles only when unavoidable
    and Component covers one capability deeply through the whole app in-process, replacing external services with test doubles
    and Integration verifies that some but not all pieces work together from the highest-level subject, mocking everything except the subjects being integrated
    and Unit covers one public surface on one subject, mocking every dependency outside that subject
    and every public surface receives native Unit tests
  when an Integration or Unit tree is added
    then it exists because the failing consumer test revealed collaboration or subject behaviour that needs direct verification
    and it is never designed up front from speculation about decomposition
  when a side effect is identified
    then it becomes an outbound port named for capability, not technology
    and the port ships in two flavours: an in-memory adapter and a real adapter
    and a shared contract suite is written for the port
    and both adapters must pass the shared suite
  when a domain object, use-case, adapter, port implementation, or other subject has a public surface
    then that public surface receives a Unit tree and native Unit test
    and dependencies outside that subject are mocked
  when an app-level invariant applies across slices rather than to one
    then it is captured at the highest test kind whose subject exposes the policy, not folded into an unrelated capability's tree
```

## sync-audits-and-resolves

```
Unit: sync-audits-and-resolves (src: skills/sync/SKILL.md; unit: test/sync-audits-and-resolves.bats; journey: test/journey/docker-entrypoint.sh)
  if the project's test trees do not exist or are empty
    then sync stops and suggests running setup first
  when sync is run
    then TEST_TREES.md is treated as the operator's expected behaviour and the coding agent's contract with the operator
    and the EARS forms bare then, while/then, when/then, where/then, and if/then are used to identify every leaf
    and causal behaviour nests beneath the outcome that makes it possible
    and labelled src / unit / integration / component / journey paths are verified against the filesystem
    and each test file's describe/it hierarchy is parsed and compared with its tree verbatim
    and every "none" value is treated as a gap to close
  when test-tree leaves are reviewed
    then subagents review every leaf
    and determine whether it is tested
    and determine whether the test expresses the operator's intention in the leaf
    and determine whether the implementation passes the test
    and determine whether the implementation fulfils the intention expressed by the leaf and test
  when source code is reviewed
    then subagents identify behaviour that is not expressed in the test trees
  when MENTAL_MODEL.md is reviewed
    then each of its seven headings is reviewed with subagents
    and each heading's representation is checked for fit and usefulness against the codebase
    and the codebase is checked for whether it honours the representation
  when a substantive unit revealed by TDD has no tree and test at its natural lowest layer
    then the missing native coverage is closed immediately through TDD
    and existing higher-layer coverage is retained
    and every applicable layer tests the behaviour at its own seam
  when the project is in sync
    then every identified issue has been resolved proactively
    and all tests pass
    and the trees, tests, implementation, and mental model agree
    and the user is suggested to run second-opinion for an independent review of the completed work
  when a Unit tree is checked
    then every observable branch in the subject's public surface corresponds to a tree path, and every tree path corresponds to a branch
    and YAGNI is evaluated separately from branch parity
  when drift is identified
    then the coding agent resolves it using the rules, mental model, trees, tests, code, and its own judgment
    and operator intention remains the guiding principle
    and only a consequential genuinely under-determined choice is escalated to the operator
    and contract changes are handled through change while test and implementation gaps are handled through tdd
```

## change-without-me-runs-end-to-end

```
Unit: change-without-me-runs-end-to-end (src: skills/change-without-me/SKILL.md; unit: test/change-without-me-runs-end-to-end.bats; journey: test/journey/docker-entrypoint.sh)
  when change-without-me is run with an idea
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
Unit: skill-discoverability (src: hooks/session-start.sh; unit: test/skill-discoverability.bats; journey: test/journey/docker-entrypoint.sh)
  when a user describes a behaviour change without naming a skill
    then the change skill is triggered
  when a user asks about drift between code and requirements without naming a skill
    then the sync skill is triggered
  when a user asks to set up testing without naming a skill
    then the setup-test-feedback skill is triggered
  when a user asks to set up conventional linting without naming a skill
    then the setup-linter skill is triggered
  when a user asks to set up architecture enforcement without naming a skill
    then the setup-architecture-linter skill is triggered
  when a user asks to fix architecture violations without naming a skill
    then the fix-architecture skill is triggered
  when a user asks to discover and test the behaviour of an existing project without naming a skill
    then the bootstrap-test-trees skill is triggered
  when a user asks to establish or repair a project mental model without naming a skill
    then the setup-mental-model skill is triggered
  when a user asks to establish behavioural test trees without implementing their tests
    then the setup-test-trees skill is triggered
  when a user asks to set up mutation testing without naming a skill
    then the setup-mutation-testing skill is triggered
  when a user asks for every Contree feedback loop without naming a skill
    then the comprehensive setup skill is triggered
  when a user asks to implement from existing requirements without naming a skill
    then the tdd skill is triggered
  when a user asks to take an idea through the full workflow without naming a skill
    then the change-without-me skill is triggered
```

## composable-testing

```
Integration: composable-testing (src: skills/setup-test-feedback/SKILL.md, skills/setup-mutation-testing/SKILL.md, skills/change/SKILL.md; integration: test/composable-testing.bats; journey: test/journey/docker-entrypoint.sh)
  when a project uses contree
    then Unit tests are colocated with their subjects (*.unit.test.*)
    and Integration tests are colocated with their highest-level subjects (*.integration.test.*)
    and Component tests live under test/component/ (*.component.test.*)
    and Journey tests live under test/journey/ (*.journey.test.*)
    and Journey tests exercise a broad production-like user arc across capabilities, replacing external services with test doubles only when unavoidable
    and Component tests exercise one capability deeply through the whole app in-process, replacing external services with test doubles
    and Integration tests start from the highest-level subject and mock everything except the subjects whose real collaboration they verify
    and Unit tests exercise every public surface on one subject while mocking every dependency outside that subject
    and every test kind produces tree-shaped output
    and mutation testing validates Unit-test quality
```

## rules-loading

```
Unit: rules-loading (src: hooks/session-start.sh; unit: test/rules-loading.bats; journey: test/journey/docker-entrypoint.sh)
  when a session starts
    then the rules list is shown
    and not repeated on every response
    and hooks.json wires session-start.sh to the SessionStart hook event
```

## dual-harness-compatibility

```
Integration: dual-harness-compatibility (src: .claude-plugin/plugin.json, .codex-plugin/plugin.json, hooks/hooks.json, test/journey/codex-deepseek-responses-proxy.mjs; integration: test/dual-harness-compatibility.bats; journey: test/journey/docker-entrypoint.sh)
  when contree is installed under either Claude Code or Codex
    then a manifest exists at .claude-plugin/plugin.json
    and a manifest exists at .codex-plugin/plugin.json declaring skills as ./skills/ and hooks as ./hooks/hooks.json
    and both manifests carry the same name and version
    and .claude-plugin/plugin.json declares a name of "contree", a version, and a description
    and one hooks/hooks.json is shared by both harnesses
  when a hook fires
    then hooks.json invokes its script via $CLAUDE_PLUGIN_ROOT — the env var both harnesses set
  when the Stop hook fires
    then hooks.json wires it to hooks/stop-drift-check.sh
  when Codex is the harness
    then Codex installations require [features].hooks and [features].plugin_hooks to be true so hooks/hooks.json is loaded
    and the automated journey matrix runs the existing functional cases under Codex
    and both journey harnesses use DeepSeek auth from DEEPSEEK_API_KEY
    and Codex journey model calls reach DeepSeek through a Responses-compatible local boundary
    and Claude journey runs fail fast without Claude provider auth
    and Codex journey runs fail fast without DeepSeek provider auth
    and the journey harness distinguishes hook runner failures from ordinary agent command failures and test framework hook timeout output
    and the journey harness distinguishes structured Codex failures from ordinary transcript text and recoverable tool diagnostics
    and the journey harness treats unavailable Codex tools as functional failures when a scenario forbids them
```

## diff-images-the-change

```
Unit: diff-images-the-change (src: skills/diff-for-humans/SKILL.md; unit: test/diff-images-the-change.bats; journey: test/journey/docker-entrypoint.sh)
  when the diff-for-humans skill is invoked
    then it determines the change to depict from any natural-language indication the user gave
    and absent a clear indication it depicts the last non-trivial, naturally grouped changes — not a single commit, since trunk-sync commits continuously, and not only the working tree
    and the change it gathers includes new files not yet tracked by git
    and untracked file diffs do not make the recipe fail when git diff --no-index reports differences
    and it generates an image representing that change using OpenAI's gpt-image-2 model via the images generations API, with OPENAI_BASE_URL selecting the API root
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
Unit: second-opinion-reviews-completed-work (src: skills/second-opinion/SKILL.md; unit: test/second-opinion-reviews-completed-work.bats; journey: test/journey/docker-entrypoint.sh)
  when the second-opinion skill is invoked
    then it determines the work to review from any natural-language indication the user gave
    and absent a clear indication it reviews the last non-trivial, naturally grouped changes — not a single commit, since trunk-sync commits continuously, and not only the working tree
    and the work it gathers includes new files not yet tracked by git
    and untracked file diffs do not make the recipe fail when git diff --no-index reports differences
    and it reads the test trees as the contract the work must satisfy
    and it sends the change and the test trees to Z.AI's GLM 5.2 via the chat completions API authenticated with ZAI_API_KEY, with ZAI_BASE_URL selecting the API root
    and it sends the change and the test trees to DeepSeek via the DeepSeek chat completions API authenticated with DEEPSEEK_API_KEY when ZAI_API_KEY is absent, with DEEPSEEK_BASE_URL selecting the API root
    and it surfaces the independent model's review to the user attributed to the model that reviewed it
  when there are no non-trivial changes to review
    then it says so and stops without calling the API
  if the review request fails — missing both ZAI_API_KEY and DEEPSEEK_API_KEY, an API error, a non-2xx response, or empty content
    then the failure is surfaced as an error and no review is fabricated
```

## validate-skill-frontmatter

```
Unit: validate-skill-frontmatter (src: scripts/validate-skill-frontmatter.sh; unit: test/validate-skill-frontmatter.bats)
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
Unit: website-explains-contree (src: website/index.html; unit: test/website-explains-contree.bats)
  when a visitor loads the contree website
    then the page bridges from test-first practice to test trees as living requirements
    and the page explains the four test kinds Journey, Component, Integration, and Unit
    and the page walks the skill workflow — setup, change, sync, tdd, second-opinion
    and the page offers change-without-me for the full arc
    and the page explains the Claude Code hook mechanics — the stdout, stderr-exit-2, and additionalContext injection channels, and the Stop-hook control flow
    and the page requires no build step
```

Note: `.github/workflows/pages.yml`, the deploy mechanism that publishes this page, lives outside `contree/` as monorepo-level shared infrastructure (one workflow staging every plugin's `website/` into its own subdirectory) and is documented in the repo-root `CLAUDE.md` rather than tree'd here — contree's own trees and tests are scoped to files under `contree/`, matching every other tree's `$PROJECT_ROOT`-relative paths.

## Cross-Functional Requirements

- Supported languages: JS/TS (Node, Bun, React, React Native), Elixir (Phoenix, Jido), Go. Setup refuses other languages and names the supported set.
- Mutation testing is omitted for Elixir — no mature tool exists. Users are pointed at property-based testing with StreamData as a substitute.
