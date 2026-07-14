---
name: change
description: "Set expected behaviour by writing or modifying test trees before code changes. TRIGGER when: the user describes a feature, capability, behaviour change, removal, or modification they want — even loosely (e.g. 'I want X', 'let's add Y', 'can we make it do Z', 'change how X works', 'remove this behaviour')."
---

# Change

Turn a requested behaviour change into a coherent edit to `TEST_TREES.md` that faithfully expresses operator intention.

Change owns trees. TDD owns tests and implementation.

Before implementation, establish the expected behaviour in trees. Trees first, code second.

## Process

### 1. Inspect Reality

Talk it through with the user and discuss the behaviour change before modifying trees.

Read the relevant mental model, trees, actual tests, and source before drafting or modifying the contract. Compare the current tree and its paths with the actual tests and source locations in the affected area.

If trees and implementation already disagree in the affected area, reconcile that pre-existing tree-code drift as part of the change so the edited tree describes one coherent intended post-change reality. Surface only consequential conflicts that cannot be resolved from the project.

### 2. Identify the Consumer

Identify:

- who or what observes the behaviour
- the interface through which it is observed
- the inputs or triggers
- the outcomes and side effects
- prevented effects and meaningful errors

Describe Journey and Component interfaces in the consumer's vocabulary. Describe an Integration test from its highest-level subject and name the other subjects whose real collaboration matters. Describe a Unit test through one public surface on one subject.

At every test kind, every test kind is consumer-driven: the consumer is created before the thing it consumes is implemented. A failing consumer test reveals which collaboration or public surface needs direct verification.

Pure functions are still consumer-driven: a caller forced the function into existence because it needs to observe its result or error.

### 3. Reflect Operator Intention

Make the tree edit that most faithfully captures what the operator intends, including observable consequences discovered while tracing the change through the system.

- Modify every existing path affected by the intended behaviour.
- Change only affected paths. Do not rewrite paths that are not changing.
- Follow the change through related trees, tests, and source to discover changed outcomes, side effects, prevented behaviour, and invariants.
- Make complementary tree adjustments wherever those consequences alter the contract.
- Add one tree for each new behavioural unit.
- Confirm with the user before removing a capability, then remove paths that no longer describe supported behaviour.
- Do not design inner trees before a failing consumer test reveals their need.

For a pure library, write a Unit tree for every public surface at the exported interface where the behaviour is consumed.

### 4. Format the Tree

Every tree begins:

```text
<Test-kind>: <Subject> (<coverage>)
```

Test kinds are `Journey`, `Component`, `Integration`, and `Unit`.

The subject is the highest-level behaviour-bearing thing observed by that test kind.

One tree, one test file. One tree maps to exactly one test file. Every tree's describe/it hierarchy mirrors the tree verbatim.

Coverage is recorded as parenthesised, semicolon-separated labelled paths:

```text
Unit: Money (src: src/money.ts; unit: src/money.unit.test.ts)
Component: save-score (component: none)
```

Labels are `src`, `unit`, `integration`, `component`, and `journey`.

Use `none` when coverage is expected but missing. Omission means a category does not apply. Coverage may be attached to a subtree when a distinct file owns that behaviour.

Treat a mismatch between the consumer need and the file boundaries as design feedback. Resolve it until the coverage is honest.

### 5. Write Observable Paths

Use the EARS form matching the requirement:

```text
then <ubiquitous outcome>

while <precondition>
  then <outcome>

when <trigger>
  then <outcome>

where <optional feature>
  then <outcome>

if <unwanted condition>
  then <recovery outcome>
```

Nest causal behaviour:

```text
when <trigger>
  then <outcome>
    when <next trigger made possible by that outcome>
      then <next outcome>
```

Journey and Component paths describe principles, not cases, in the consumer's vocabulary. Integration and Unit paths describe observable behaviour at their subjects' public interfaces. Each path must:

- describe observable behaviour, including side effects
- state principles rather than enumerate cases
- add information rather than restate its condition
- include meaningful negative behaviour
- ensure each leaf stands alone without cross-leaf references such as "see above" or "as before"
- use consumer vocabulary rather than implementation details

When behaviour is described as "just like" existing behaviour, duplicate the existing tree's paths in full. If duplication reveals one shared concept, collapse the subjects into one tree and let one generic implementation serve both.

Every `then` adds information that its condition does not already imply. Reject tautological outcomes.

Causal nesting is mandatory: a `when` trigger made possible only by a preceding `then` outcome is not a sibling — it is a child of that outcome.

### 6. Choose Test Kinds from Consumer Pressure

Capture the outermost consumer tree first: a Journey tree for a broad user arc, or a Component tree for one whole-app capability. Write only the outermost tree up front. A failing consumer test creates pressure for Integration and Unit trees.

Plan possible movement into Integration and Unit without designing those trees. The higher-level tree and failing consumer test create demand for the next subject. Designing Integration or Unit trees from speculation is a YAGNI failure; a tree is not designed ahead of time when its consumer has not asked for it.

Write one tree per behavioural subject at its test kind. Name every tree for the highest-level subject with observable behaviour at that test kind.

The test kinds are:

- Journey: broad, production-like test of a curated user arc across capabilities, with external services replaced by test doubles only if unavoidable.
- Component: deep in-process test of one capability through the whole app, with external services replaced by test doubles.
- Integration: when concerned integration of some (but not all) pieces, test from the highest-level subject and mock everything except the subjects you are integrating to see if they really work together as expected.
- Unit: test of one public surface on one subject; every public surface gets native unit tests, and every dependency outside the subject is mocked.

Every test kind is consumer-driven. The current tree and failing consumer test create demand for the next subject. Do not create one test of every kind by default.

Every public surface on a domain object, use-case, adapter, port implementation, or other subject receives a Unit tree and native Unit test. Dependencies outside that subject are mocked.

An Integration tree exists only when the concern is whether named subjects really work together. Start from the highest-level subject and mock everything except the subjects being integrated.

### 7. Model Outbound Capabilities

When a side effect is identified, define an outbound port named for the capability, not technology. Ship the port in two flavours: an in-memory adapter and a real adapter. Write one shared behavioural suite for the port; both adapters must pass the shared behavioural suite through their Unit tests.

Use an Integration test only when the concern is collaboration between a port implementation and other real subjects. Mock every dependency outside the subjects being integrated.

### 8. Handle Cross-Cutting and Pure Behaviour

Capture an app-level policy at the highest test kind whose subject exposes that policy rather than folding it into an unrelated capability's tree.

For a pure library, give every public surface a Unit tree. Add an Integration tree only when the concern is whether multiple library subjects really work together.

### 9. Let Tests Reveal the Subjects

TDD turns the current tree into a failing consumer test. Its failure reveals the next missing behaviour or boundary.

When that failure exposes another subject:

1. Add the subject's Integration or Unit tree.
2. Write its failing test at its own interface.
3. Follow that failure until the behaviour reaches the public surface that owns it.
4. Implement only after that native failing test exists.
5. Make the consuming tests pass.

Introduce only enough real structure to expose the next meaningful failure. Do not add placeholder production behaviour to satisfy an outer test.

The relevant test kinds are:

- Journey: broad, production-like test of a curated user arc across capabilities, with external services replaced by test doubles only if unavoidable.
- Component: deep in-process test of one capability through the whole app, with external services replaced by test doubles.
- Integration: when concerned integration of some (but not all) pieces, test from the highest-level subject and mock everything except the subjects you are integrating to see if they really work together as expected.
- Unit: test of one public surface on one subject; every public surface gets native unit tests, and every dependency outside the subject is mocked.

Architecture positions such as domain, use-case, adapter, and port do not create additional test kinds. Their public surfaces receive Unit tests; selected collaborations receive Integration tests.

When a use-case needs an outbound capability, follow the outbound-port rules above.

## Finish

Leave `TEST_TREES.md` with the coherent contract that best reflects operator intention. Present the completed trees to the user for alignment and suggest running `sync`. Report what changed. Implementation proceeds through TDD.

Every tree's first line is `<Test-kind>: <Subject> (<coverage>)`. Without the test-kind prefix, readers and sync cannot detect duplication across test kinds.
