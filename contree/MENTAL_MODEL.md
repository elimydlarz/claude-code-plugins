## Core Domain Identity

- Contree makes test trees the living contract: `TEST_TREES.md` IS the specification, kept in sync with implementation, never a stale parallel doc.
- Development is outside-in and consumer-driven: each behaviour goes RED, GREEN, then REFACTOR; excessive branching is extracted behind a mock and throwing stub, signalling a new TDD cycle for that unit.
- A tree is both specification (EARS `then`, `while`, `when`, `where`, and `if` forms in `TEST_TREES.md`) and structure (the test file's describe/it hierarchy, mirrored verbatim).
- It ships as one product from one `contree/` directory under two harnesses (Claude Code, Codex) via parallel manifests over shared `skills/` and `hooks/`.
- Coding rules (KISS, fail-fast, hexagonal, no comments, …) ride alongside the trees as the always-on operating discipline.

## World-to-Code Mapping

- Expected behaviour → a tree in `TEST_TREES.md`; anything observable anywhere (files, network, logs, next invocation) belongs there.
- One tree → exactly one test file; the tree's EARS paths → that file's describe/it hierarchy, verbatim.
- The user-visible arc across capabilities → the **Journey** layer (`test/journey/*.journey.test.*`), the outermost layer and outside-in entry point.
- A single capability wired whole-app → the **System** layer (real infrastructure; `test/system/*.system.test.*`) and the **Component** layer (externals doubled at the edge — in-memory database, stubbed outbound HTTP; `test/component/*.component.test.*`), both interior to the Journey.
- Hexagonal seams → inner layers: Adapter (`*.adapter.test.*`), Use-case (`*.use-case.test.*`), Domain (`*.domain.test.*`).
- A tree's coverage on disk → a parenthesised label set, one per layer: `src`, `domain`, `use-case`, `adapter`, `component`, `system`, `journey`; `none` marks a declared gap.
- An outbound dependency → a Port; each Port ships an in-memory twin plus a real adapter, both bound by one shared `*.contract.ts` suite.
- Project steering → focused setup skills for test feedback, conventional lint, architecture lint and repair, test-tree bootstrap, and mutation feedback; `setup` orchestrates the complete suite.
- Behaviour workflow → skills: `change`, `sync`, `tdd`, `second-opinion`, `workflow`.
- Enforcement → hooks: SessionStart (rules + trees) and Stop (drift check).
- The product's theory → `MENTAL_MODEL.md` (this file); its behaviour → `TEST_TREES.md`; its operating discipline → the rules.

## Ubiquitous Language

- Test tree — an EARS hierarchy that is simultaneously requirement and test structure.
- Leaf — a single `then`/`and`/`but` assertion at behaviour granularity.
- EARS keywords — `when` (event), `while` (state), `if` (unwanted), `where` (optional), bare `then` (ubiquitous).
- Causal nesting — a `when` that can only occur after a prior `then` nests under it, not as a sibling.
- Journey — the outermost layer: a curated, non-exhaustive user arc across capabilities and contexts, at max realism, kept runnable in under 5 minutes, walking representative errors and eventually succeeding.
- System — a single capability wired whole-app against real infrastructure, interior to the Journey; validates the same surface a Component test covers, selectively.
- Component — that same whole-app capability with externals doubled only at the edge (in-memory database, stubbed outbound HTTP); in-process, exhaustive, cheap.
- Adapter / Use-case / Domain — one adapter vs its contract / orchestration over in-memory ports / the pure core.
- Port — an outbound interface; ships an in-memory twin and a real adapter.
- Shared contract suite — one `*.contract.ts` both adapters must pass, making in-memory substitution sound.
- Slice — one consumer-visible capability; a Journey traverses several.
- Outside-in — start from the current tree's consumer, implement its behaviour, then let its passing tests reveal deeper units.
- Mocked unit — a unit imagined to own some observed branching; its mock passes consumer tests while its stub throws `NotImplemented` until the unit is TDDed.
- Coverage-by-proxy — a unit reachable only through higher-layer tests with no tree at its native layer; treated as uncovered.
- Drift — divergence between trees and implementation in either direction.
- Coverage categories — one per layer: `src`, `domain`, `use-case`, `adapter`, `component`, `system`, `journey`.

## Bounded Contexts

- Tree language — EARS syntax, causal nesting, one-tree-one-file, leaf granularity; the grammar of the contract.
- Test-layer taxonomy — Journey ▸ System ▸ Component ▸ Adapter ▸ Use-case ▸ Domain (+ Port contract); each layer owns its own seam.
- Setup suite — focused skills establish test, lint, architecture, behavioural-contract, and mutation feedback independently; `setup` dynamically orchestrates the comprehensive operator-guided workflow.
- Skill workflow — `change` (set behaviour) → `sync` (audit and fulfil the contract) → `tdd` (close gaps) → `second-opinion` (independent review from another model); `workflow` runs the arc.
- Enforcement hooks — plugin SessionStart and drift-check Stop hooks, plus setup-generated project hooks for save-time lint autofix, impacted tests, and architecture checks.
- Hexagonal architecture — domain pure, I/O in adapters, dependencies inward, a boundary linter holding the line.
- Dual-harness packaging — one source directory, parallel `.claude-plugin` / `.codex-plugin` manifests, `CLAUDE_PLUGIN_ROOT` shared by both.

## Invariants

- Trees are the contract: every behaviour/side-effect has a tree; every tree has a test; every test drives real implementation.
- One tree reifies exactly one test file; the describe/it hierarchy mirrors the tree verbatim.
- Outside-in TDD begins with the current tree's consumer and keeps implementation flat through RED and GREEN before REFACTOR reveals branching under different conditions.
- Excessive branching creates a mock and a `NotImplemented` stub; passing consumer tests plus failing code signal that the unit receives its own tree and repeats TDD from step 1.
- The original consumer test remains while every mocked unit gains its own complete tree and tests; overlap proves different subjects.
- Use-case is to Component as Journey is to System: the cheap tier (Use-case in-memory twins; Component real adapters with edges doubled) is always written and exhaustive; the real tier (System, Journey; real infrastructure) is selective. Component and System cover the same single-capability surface at two realism levels.
- Each outbound Port has an in-memory twin and a real adapter, both bound by one shared contract suite.
- Drift is resolved toward operator intention with `TEST_TREES.md` authoritative; only consequential conflicts that project evidence cannot settle return to the operator.
- Consumer-driven, not internals-driven: each tree describes what its consumer observes; outside-in tests create the consumer before the consumed unit is implemented.
- Shared hook scripts preserve enforcement across Claude Code and Codex.

## Decision Rationale

- Journey is canonised as distinct from System so the outside-in entry point is a real multi-capability arc — not a per-capability System test pressed into doing the arc's job; it is kept curated and under 5 minutes (highest-impact + most-recent steps) because it cannot be exhaustive — the lower layers carry the rest.
- Mock-and-stub extraction prevents speculative decomposition: a lower unit exists only after branching demands it, with passing mock-based tests and a throwing stub making the unfinished work explicit.
- Hexagonal layering is chosen over "unit/integration/functional" because seams give sharper targets; a green higher layer can still hide an untested seam. The cheap tier splits into Use-case (behaviour, in-memory twins) and Component (system, real adapters with edges doubled) so the assembled wiring the twins skip is still covered exhaustively without paying for real infrastructure.
- Trees live in `TEST_TREES.md`, not a separate requirements doc, so spec and tests can never drift into two truths.
- One source directory with parallel manifests avoids duplicating skills/hooks per harness; `CLAUDE_PLUGIN_ROOT` lets shared scripts run on both while harness adapters handle Codex-specific payload and transcript differences.
- Enforcement is hook-driven rather than advisory prose, because rules in text alone get ignored under pressure.
- Setup is split by feedback loop so each steering mechanism can be installed, run, repaired, and verified independently; comprehensive setup composes only the work the project needs.
- The mental model is fixed at seven capped sections so it stays a theory, not a dumping ground.

## Temporal View

- Per project: run focused setup skills as steering needs change, or `setup` for the comprehensive suite; then repeat `change` → `sync` → `tdd` → `second-opinion` cycles (or `workflow` end-to-end).
- Per behaviour: write one test → RED → implement to GREEN → REFACTOR excessive branching → create mock and throwing stub → green the consumer tests → repeat from step 1 for the unit.
- Per failing test: write one, run it, see it fail, implement the minimum, see it pass; never batch.
- Per turn: the Stop hook fires a drift check after each response, with `stop_hook_active` preventing the hook from checking its own drift-check turn.
- At end of work: mutation testing runs against Domain and Use-case as final validation.
- Across sessions: SessionStart injects rules, mental model, and trees so every session starts in-context.
