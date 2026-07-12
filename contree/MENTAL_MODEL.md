## Core Domain Identity

- Contree makes `TEST_TREES.md` the living expression of operator intention and the coding agent's contract; Sync keeps trees, faithful tests, implementation, and the mental model in agreement with the intention shared by each leaf and test.
- Development is outside-in and consumer-driven: each observable behaviour goes RED, GREEN, then REFACTOR; excessive branching is extracted behind a mock and throwing stub, signalling a new TDD cycle for that unit.
- A tree is both specification (EARS `then`, `while`, `when`, `where`, and `if` forms in `TEST_TREES.md`) and structure (the test file's describe/it hierarchy, mirrored verbatim).
- Coding rules (KISS, fail-fast, hexagonal, no comments, …) are injected at SessionStart as session-wide operating discipline alongside the mental model and trees.

## World-to-Code Mapping

- Operator-expected observable behaviour and side effects → EARS trees in `TEST_TREES.md`, the coding agent's contract with the operator; files, network, logs, and the next invocation all count as observable.
- One `<Layer>: <Subject>` tree → exactly one test file; the tree's EARS paths → that file's describe/it hierarchy, verbatim.
- The user-visible arc across capabilities → the **Journey** layer (`test/journey/*.journey.test.*`), the outermost layer and outside-in entry point.
- A single capability wired whole-app → the **System** layer (real infrastructure; `test/system/*.system.test.*`) and the **Component** layer (real adapters with external services doubled only at the edge; `test/component/*.component.test.*`), both interior to the Journey.
- Hexagonal seams → inner layers: Adapter (`*.adapter.test.*`), Use-case (`*.use-case.test.*`), Domain (`*.domain.test.*`).
- A tree's implementation and overlapping test coverage on disk → parenthesised labelled paths: `src`, `domain`, `use-case`, `adapter`, `component`, `system`, `journey`; `none` marks expected coverage not yet fulfilled, while inapplicable labels are omitted.
- An outbound capability → a Port with an in-memory twin and real adapter, both passing one shared Port-contract suite.
- Project steering → focused setup skills for test feedback, conventional lint, architecture lint and repair, test-tree bootstrap, and mutation feedback; `setup` orchestrates the complete suite.
- Behaviour responsibility → `change` owns the operator contract; `tdd` owns tests and implementation; `sync` audits and resolves agreement across intention, trees, tests, code, and mental model; `second-opinion` reviews independently; `workflow` composes the arc.
- Lifecycle hooks → SessionStart injects rules, mental model, and trees; Stop prompts review of the model, tree/implementation drift, CLAUDE.md, and README.
- The product's theory → `MENTAL_MODEL.md` (this file); its behaviour → `TEST_TREES.md`; its operating discipline → the rules.

## Ubiquitous Language

- Test tree — an EARS hierarchy that is simultaneously requirement and test structure.
- Leaf — a single `then`/`and`/`but` assertion at behaviour granularity.
- EARS keywords — `when` (trigger), `while` (precondition), `if` (unwanted condition), `where` (optional feature), bare `then` (ubiquitous outcome).
- Causal nesting — a `when` that can only occur after a prior `then` nests under it, not as a sibling.
- Journey — the outermost layer: a curated, non-exhaustive user arc across capabilities and contexts at maximum realism, kept runnable in under 5 minutes.
- System — a single capability wired whole-app against real infrastructure, interior to the Journey; validates the same surface a Component test covers, selectively.
- Component — that same whole-app capability with externals doubled only at the edge (in-memory database, stubbed outbound HTTP); in-process, exhaustive, cheap.
- Adapter — a concrete boundary implementation tested against the real boundary it adapts; Unit — one public surface on one subject; Domain and Use-case locate Unit tests at their respective hexagonal positions.
- Port — an outbound application interface with an in-memory twin and real adapter; both pass one shared Port-contract suite, making substitution sound.
- Slice — one consumer-visible capability; a Journey traverses several.
- Outside-in — select the current consumer's tree leaf, observe its test RED, implement GREEN, then let branching observed during REFACTOR reveal a deeper unit.
- Mocked unit — a unit revealed to own observed branching; consumer tests pass only when its mock is consumed correctly, while its real stub throws `NotImplemented` until the unit is TDDed.
- Native coverage — every substantive unit revealed by TDD has its own tree and test at its natural lowest layer; higher-layer overlap never substitutes for it.
- Drift — disagreement among operator intention, trees, tests, coverage, implementation, or the mental model.
- Coverage labels — `src`, `domain`, `use-case`, `adapter`, `component`, `system`, `journey`; `none` means expected but missing, while omission means inapplicable.

## Bounded Contexts

- Tree language — EARS syntax, causal nesting, one-tree-one-file, leaf granularity; the grammar of the contract.
- Test seams — Journey owns a multi-capability arc; System and Component own one capability at different realism; Adapter and Port contract own boundaries; Use-case and Domain own unit interfaces.
- Setup suite — focused skills establish test, lint, architecture, behavioural-contract, and mutation feedback independently; `setup` dynamically orchestrates the comprehensive operator-guided workflow.
- Skill ownership — `change` owns trees; `tdd` owns tests and implementation; `sync` audits and resolves agreement across operator intention, trees, tests, code, and mental model; `second-opinion` reviews independently; `workflow` composes them.
- Enforcement hooks — plugin SessionStart injects discipline and plugin Stop prompts documentation reconciliation; setup-generated project hooks run impacted normal tests and architecture checks at Stop, and lint autofix after saves.
- Hexagonal architecture — domain pure, I/O in adapters, dependencies inward, a boundary linter holding the line.
- Dual-harness packaging — one source directory, parallel `.claude-plugin` / `.codex-plugin` manifests, `CLAUDE_PLUGIN_ROOT` shared by both.

## Invariants

- Trees are the operator contract: every operator-expected observable behaviour and side effect has a tree; every tree has a faithful test; every test drives fulfilling implementation.
- One tree reifies exactly one test file; the describe/it hierarchy mirrors the tree verbatim.
- Outside-in TDD begins with the current tree's consumer and keeps implementation flat through RED and GREEN before REFACTOR reveals branching under different conditions.
- Excessive branching creates a mock and a `NotImplemented` stub; passing consumer tests plus the real stub's loud runtime failure signal that the unit receives its own tree and repeats TDD from step 1.
- Every substantive unit revealed by TDD has a tree and native test at its natural lowest layer; its consumer coverage remains, and every applicable layer tests the behaviour at its own seam.
- When applicable, the cheap tier (Use-case with in-memory twins; Component with external services doubled at the edge) is exhaustive and the real tier (System and Journey with real infrastructure) is selective; Component and System cover the same capability surface at different realism.
- Each outbound Port has an in-memory twin and a real adapter, both bound by one shared contract suite.
- Drift is resolved toward operator intention with `TEST_TREES.md` its authoritative expression; only consequential conflicts that project evidence cannot settle return to the operator.
- Consumer-driven, not internals-driven: each tree describes what its consumer observes; outside-in tests create the consumer before the consumed unit is implemented.
- Sync delegates three exhaustive audits to subagents and reconciles their evidence: every leaf through faithful test to fulfilling implementation, all production code back toward the trees, and every mental-model heading for useful fit and code compliance.

## Decision Rationale

- Journey is distinct from System so the outside-in entry point can express a curated multi-capability arc while lower seams carry exhaustive breadth.
- Mock-and-stub extraction prevents speculative decomposition: a lower unit exists only after observed branching demands it, with consumer tests passing through the mock and the throwing stub making unfinished runtime work explicit.
- Tests are classified by observable seam because green higher-layer coverage cannot prove a lower seam; every applicable seam retains overlapping coverage, native lowest-layer coverage is mandatory, and YAGNI separately prevents unrevealed units.
- Trees live in `TEST_TREES.md` as the single operator-owned behaviour contract rather than a second requirements document; one-tree/one-test structure makes drift inspectable and Sync resolves it.
- Literal green assertions are insufficient for an operator contract, so Sync checks the intention shared by leaf, test, and implementation, resolves evidence-settled drift proactively, and escalates only genuinely under-determined conflicts.
- One source directory and lifecycle hooks serve both harnesses: parallel manifests avoid duplicated skills, `$CLAUDE_PLUGIN_ROOT` resolves shared hooks, SessionStart injects context, and Stop prompts reconciliation.
- Setup is split by feedback loop so each steering mechanism can be installed, run, repaired, and verified independently; comprehensive setup composes only the work the project needs.
- The mental model uses seven fixed, bounded sections with merge and displacement discipline so it remains a theory rather than a dumping ground.

## Temporal View

- Per project: run focused setup skills as steering needs change, or `setup` for the comprehensive suite; then repeat `change` → `sync` → `tdd` → `second-opinion` cycles (or `workflow` end-to-end).
- Per behaviour: write one test → RED → implement to GREEN → REFACTOR excessive branching → create mock and throwing stub → green the consumer tests → repeat from step 1 for the unit.
- Per failing test: write one, run it, see it fail, implement the minimum, see it pass; never batch.
- Per turn: the Stop hook fires a drift check after each response, with `stop_hook_active` preventing the hook from checking its own drift-check turn.
- At end of work: mutation testing runs against Domain and Use-case as final validation.
- Across sessions: SessionStart injects rules, mental model, and trees so every session starts in-context.
