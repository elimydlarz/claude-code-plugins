---
name: bootstrap-test-trees
description: "Discover an existing project's supported behaviour and establish its mental model, test trees, and tests, or create empty Contree homes for a new project. TRIGGER when: the operator asks to bootstrap, backfill, or establish test trees for a project."
---

# Bootstrap Test Trees

Establish the contract and its tests from project evidence. Existing projects require operator alignment and two reconciled subagent waves. New projects receive only the empty homes that let the first requested capability pull behaviour into existence.

## Distinguish the Project

Read the project root, source, tests, configuration, consumer documentation, `MENTAL_MODEL.md`, and `TEST_TREES.md` when present.

A project is existing when it already has consumer-visible behaviour. A project is new when it has no consumer-visible behaviour, even if manifests or empty source directories exist.

## Existing Project

### Agree the Scope

Explain the evidence that discovery will gather: observable behaviour, existing tests, architecture, and mental-model concepts.

Propose complete, non-overlapping behavioural areas based on the project evidence. Agree the behavioural scope with the operator before dispatching discovery. Include every area in scope exactly once.

### Discover in Parallel

Dispatch subagents across the agreed non-overlapping areas. Give each subagent explicit ownership boundaries and require evidence from the files it inspected.

Each discovery subagent returns:

- behaviour visible to a consumer at the area's public seams
- inputs, outputs, side effects, prevented effects, and meaningful errors
- existing tests and the behaviour they prove
- architecture and dependency boundaries
- mental-model concepts, vocabulary, decisions, and invariants
- contradictions or unsupported claims in existing documentation or tests

Discovery is read-only. Subagents do not edit source, tests, `MENTAL_MODEL.md`, or `TEST_TREES.md`.

### Reconcile the Contract

Reconcile all discovery evidence yourself. Resolve overlap, vocabulary differences, and contradictions against direct project evidence.

Reconcile the result into one coherent `MENTAL_MODEL.md` and `TEST_TREES.md` with the operator. When `MENTAL_MODEL.md` is missing, create it with these seven H2 sections in order:

1. `## Core Domain Identity`
2. `## World-to-Code Mapping`
3. `## Ubiquitous Language`
4. `## Bounded Contexts`
5. `## Invariants`
6. `## Decision Rationale`
7. `## Temporal View`

Use `change` to create or modify the test-tree contract. Every discovered behaviour is expressed at its consumer-visible seam. Do not invent unsupported behaviour. Every tree names honest coverage, including `none` for tests that the implementation wave must add.

Present the reconciled mental model and trees to the operator and obtain agreement before tests are implemented.

### Implement the Tests

Start a second wave of subagents only after the operator agrees the contract. Partition complete non-overlapping trees across the second wave of subagents. One tree belongs to exactly one subagent.

Each implementation subagent uses `tdd` for its owned trees and:

- writes one test at a time and observes RED before trusting it
- implements tests at each tree's native seam
- makes each test hierarchy mirror its tree verbatim
- updates the tree's coverage path when its test file is created
- creates no placeholder, skipped, or fake tests
- runs the narrowest owning test after every test addition

Subagents do not weaken trees to make tests pass and do not edit trees outside their ownership.

Reconcile the test implementations yourself. Resolve overlaps and ensure each tree maps to exactly one test file and each test file maps to exactly one tree. Run the project's normal and functional test commands.

## New Project

Create a seven-section `MENTAL_MODEL.md` containing the seven H2 headings in the exact order listed above, with one concise line under each heading describing what belongs there.

Create an empty `TEST_TREES.md` containing only a heading and one sentence identifying it as the home for the project's test trees.

Do not write behaviour trees or tests. Leave them to be pulled into existence by the first requested capability through `change` and `tdd`.

## Disagreement

If a bootstrapped test exposes behaviour that disagrees with the operator's intended contract, leave the disagreement visible and route it through `change` or `tdd`.

Use `change` when the agreed contract needs correction. Use `tdd` when the implementation must be brought into agreement with the contract. Do not weaken the trees or tests, accept a failing test as supported behaviour, or silently rewrite operator intention.

## Complete

For an existing project, bootstrap is complete only when:

- the operator agreed the behavioural scope and reconciled contract
- discovery covered every agreed area exactly once
- `MENTAL_MODEL.md` and `TEST_TREES.md` form one coherent account of the project
- every tree has one test file whose hierarchy mirrors it verbatim
- normal and functional test commands pass

For a new project, bootstrap is complete when the seven-section mental-model home and empty test-tree home exist and no behaviour tree or test was created.
