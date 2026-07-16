## Core Domain Identity

- Contree makes `TEST_TREES.md` the living expression of operator intention and the coding agent's contract; Sync keeps trees, faithful tests, implementation, and the mental model in agreement with the intention shared by each leaf and test.
- Development is outside-in and consumer-driven: each observable behaviour goes RED, GREEN, then REFACTOR; excessive branching is extracted behind a mock and throwing stub, signalling a new TDD cycle for that unit.
- A tree is both specification (EARS `then`, `while`, `when`, `where`, and `if` forms in `TEST_TREES.md`) and structure (the test file's describe/it hierarchy, mirrored verbatim).
- Coding rules (KISS, fail-fast, hexagonal, no comments, …) are injected at SessionStart as session-wide operating discipline alongside the mental model and trees.

## World-to-Code Mapping

- Operator-expected observable behaviour and side effects → EARS trees in `TEST_TREES.md`, the coding agent's contract with the operator; files, network, logs, and the next invocation all count as observable.
- One `<Layer>: <Subject>` tree → exactly one test file; the tree's EARS paths → that file's describe/it hierarchy, verbatim.
- A broad production-like user arc across capabilities → **Journey** (`test/journey/*.journey.test.*`), with external services doubled only when unavoidable.
- One capability deeply through the whole app with real infrastructure → **System** (`test/system/*.system.test.*`).
- One capability deeply through the whole app in-process → **Component** (`test/component/*.component.test.*`), with external services doubled.
- One concrete boundary implementation against the real boundary it adapts → **Adapter**.
- Non-trivial application orchestration at its public seam → **Use-case**; substantive pure rules at their public seam → **Domain**.
- An outbound application interface → **Port**, with an in-memory twin and real adapter both passing one shared contract suite.
- A tree's implementation and test coverage on disk → parenthesised labelled paths: `src`, `domain`, `use-case`, `adapter`, `component`, `system`, `journey`; `none` marks expected coverage not yet fulfilled, while inapplicable labels are omitted.
- Project steering → focused setup skills for test feedback, conventional lint, architecture lint and repair, mental-model steering, test-tree steering, test-tree bootstrap, and mutation feedback; `setup` orchestrates the complete suite.
- Behaviour responsibility → `change` owns the operator contract; `tdd` owns tests and implementation; `sync` audits and resolves agreement across intention, trees, tests, code, and mental model; `second-opinion` reviews independently; `change-without-me` composes the arc.
- Lifecycle hooks → SessionStart injects rules, mental model, and trees; Stop prompts review of the model, tree/implementation drift, CLAUDE.md, and README.
- The product's theory → `MENTAL_MODEL.md` (this file); its behaviour → `TEST_TREES.md`; its operating discipline → the rules.

## Ubiquitous Language

- Test tree — an EARS hierarchy that is simultaneously requirement and test structure.
- Leaf — a single `then`/`and`/`but` assertion at behaviour granularity.
- EARS keywords — `when` (trigger), `while` (precondition), `if` (unwanted condition), `where` (optional feature), bare `then` (ubiquitous outcome).
- Causal nesting — a `when` that can only occur after a prior `then` nests under it, not as a sibling.
- Journey — a broad, production-like test of a curated user arc across capabilities, with external services replaced by test doubles only if unavoidable.
- System — a deep, production-like test of one capability through the whole app with real driven adapters and infrastructure.
- Component — a deep in-process test of one capability through the whole app, with external services replaced by test doubles.
- Adapter — a test of one concrete boundary implementation against the real HTTP, CLI, database, filesystem, queue, or third-party boundary it adapts.
- Use-case — exhaustive coverage of non-trivial application orchestration at its public seam, with dependencies outside the subject replaced.
- Domain — exhaustive coverage of substantive pure rules at their public seam.
- Port — an outbound application interface with an in-memory twin and real adapter; both pass one shared contract suite, making substitution sound.
- Slice — one consumer-visible capability; a Journey traverses several.
- Outside-in — select the current consumer's tree leaf, observe its test RED, implement GREEN, then let branching observed during REFACTOR reveal a deeper unit.
- Mocked unit — a unit revealed to own observed branching; consumer tests pass only when its mock is consumed correctly, while its real stub throws `NotImplemented` until the unit is TDDed.
- Native coverage — each substantive public seam has a tree and test at its natural layer; higher-layer overlap exists only where that layer observes a distinct concern.
- Drift — disagreement among operator intention, trees, tests, coverage, implementation, or the mental model.
- Coverage labels — `src`, `domain`, `use-case`, `adapter`, `component`, `system`, `journey`; `none` means expected but missing, while omission means inapplicable.

## Bounded Contexts

- Tree language — EARS syntax, causal nesting, one-tree-one-file, leaf granularity; the grammar of the contract.
- Test layers — Journey owns a broad production-like arc; System owns one production-like capability; Component owns one in-process capability; Adapter owns a concrete boundary; Use-case and Domain own native public seams; Port owns substitutability across implementations.
- Setup suite — focused skills establish test, lint, architecture, mental-model, behavioural-contract, and mutation feedback independently; bootstrap composes mental-model and tree setup before implementing tests, and `setup` dynamically orchestrates the comprehensive operator-guided workflow.
- Skill ownership — `change` owns trees; `tdd` owns tests and implementation; `sync` audits and resolves agreement across operator intention, trees, tests, code, and mental model; `second-opinion` reviews independently; `change-without-me` composes them.
- Enforcement hooks — plugin SessionStart injects discipline and plugin Stop prompts documentation reconciliation; each focused setup skill expands durable project-local steering, including model and tree context at SessionStart, lint autofix after edits, and impacted tests, architecture, relevant incremental mutation, model reconciliation, and tree reconciliation at Stop.
- Hexagonal architecture — domain pure, I/O in adapters, dependencies inward, a boundary linter holding the line.
- Dual-harness packaging — one source directory, parallel `.claude-plugin` / `.codex-plugin` manifests, `CLAUDE_PLUGIN_ROOT` shared by both.

## Invariants

- Trees are the operator contract: every operator-expected observable behaviour and side effect has a tree; every tree has a faithful test; every test drives fulfilling implementation.
- One tree reifies exactly one test file; the describe/it hierarchy mirrors the tree verbatim.
- Outside-in TDD begins with the current tree's consumer and keeps implementation flat through RED and GREEN before REFACTOR reveals branching under different conditions.
- Excessive branching creates a mock and a `NotImplemented` stub; passing consumer tests plus the real stub's loud runtime failure signal that the unit receives its own tree and repeats TDD from step 1.
- Every substantive public surface has native coverage at its Domain, Use-case, Adapter, or Port seam; dependencies outside the subject are replaced at Domain and Use-case seams.
- Component, System, and Journey tests are added only when their distinct in-process capability, production-like capability, or broad arc concern applies; Contree does not require every layer for each behaviour.
- Each outbound Port has an in-memory twin and a real adapter, both bound by one shared contract suite.
- Drift is resolved toward operator intention with `TEST_TREES.md` its authoritative expression; only consequential conflicts that project evidence cannot settle return to the operator.
- Consumer-driven, not internals-driven: each tree describes what its consumer observes; outside-in tests create the consumer before the consumed unit is implemented.
- Sync delegates three exhaustive audits to subagents and reconciles their evidence: every leaf through faithful test to fulfilling implementation, all production code back toward the trees, and every mental-model heading for useful fit and code compliance.
- Setup accumulates steering monotonically: every focused phase preserves earlier project hooks, proves its own feedback through actual agent turns, and leaves later agents with richer in-project guidance.

## Decision Rationale

- Seven layers classify the observable seam directly: Journey, System, Component, Adapter, Use-case, Domain, and Port.
- Mock-and-stub extraction prevents speculative decomposition: a lower unit exists only after observed branching demands it, with consumer tests passing through the mock and the throwing stub making unfinished runtime work explicit.
- Domain, Use-case, Adapter, and Port name native hexagonal seams, while Component, System, and Journey validate progressively broader consumer behavior.
- Trees live in `TEST_TREES.md` as the single operator-owned behaviour contract rather than a second requirements document; one-tree/one-test structure makes drift inspectable and Sync resolves it.
- Literal green assertions are insufficient for an operator contract, so Sync checks the intention shared by leaf, test, and implementation, resolves evidence-settled drift proactively, and escalates only genuinely under-determined conflicts.
- One source directory and lifecycle hooks serve both harnesses: parallel manifests avoid duplicated skills, `$CLAUDE_PLUGIN_ROOT` resolves shared hooks, SessionStart injects context, and Stop prompts reconciliation.
- Setup is split by feedback loop so each steering mechanism can be installed, run, repaired, and verified independently; mental-model and test-tree setup are distinct, bootstrap composes them before implementing tests, and comprehensive setup composes only the work the project needs.
- The mental model uses seven fixed, bounded sections with merge and displacement discipline so it remains a theory rather than a dumping ground.

## Temporal View

- Per project: each focused setup skill expands project-local hooks and proves the newly installed steering; bootstrap orders mental-model setup → test-tree setup → test implementation; `setup` composes the comprehensive harness; thereafter each behaviour skill runs when triggered, while `change-without-me` composes `change` → `sync` → `tdd` → Domain/Use-case mutation validation unless explicitly skipped → completion sync → `second-opinion`, repeating the completion gates for actionable review findings without routine phase pauses.
- Per behaviour: select one contracted tree leaf → write one test → RED → implement to GREEN → REFACTOR excessive branching behind a mock and throwing stub → add the revealed unit's tree → repeat from RED at that unit's public seam.
- Per sync: run the full suite → partition every leaf, all production code, and all seven mental-model headings across subagents → reconcile evidence → resolve every finding → rerun affected tests and the full suite until contract, tests, implementation, and mental model agree.
- Per turn: the Stop hook prompts reconciliation after each response, with `stop_hook_active` preventing it from reviewing its own follow-up turn.
- Across sessions: SessionStart injects rules, mental model, and trees so every session starts in-context.
