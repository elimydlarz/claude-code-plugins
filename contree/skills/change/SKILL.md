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

Describe outer interfaces in the consumer's vocabulary. Describe an inner unit using its own public inputs, outputs, and errors, but only when an existing consumer has forced that unit into existence.

At every layer, every layer is consumer-driven: the consumer is created before the thing it consumes is implemented. Domain, Use-case, and Port trees express what the outer consumer forced into existence and needs to observe.

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

For a pure library, write the tree at the exported interface where the behaviour is consumed. Capture an invariant spanning slices as a System tree named for the policy.

### 4. Format the Tree

Every tree begins:

```text
<Layer>: <Subject> (<coverage>)
```

Layers are `Journey`, `System`, `Component`, `Adapter`, `Use-case`, `Domain`, and `Port`.

The subject is the behaviour-bearing thing observed at that layer.

One tree, one test file. One tree maps to exactly one test file. Every tree's describe/it hierarchy mirrors the tree verbatim.

Coverage is recorded as parenthesised, semicolon-separated labelled paths:

```text
Domain: Money (src: src/money.ts; domain: src/money.domain.test.ts)
System: save-score (system: none)
```

Labels are `src`, `domain`, `use-case`, `adapter`, `component`, `system`, and `journey`.

Use `none` when coverage is expected but missing. Categories that do not apply are omitted. Coverage may be attached to a subtree when a distinct file owns that behaviour.

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

Journey, System, Component, and Adapter paths describe principles, not cases, in the consumer's vocabulary. Each path must:
- describe observable behaviour, including side effects
- describe principles rather than enumerate cases
- add information rather than restate its condition
- include meaningful negative behaviour
- ensure each leaf stands alone without cross-leaf references such as "see above" or "as before"
- use consumer vocabulary rather than implementation details

When behaviour is described as "just like" existing behaviour, duplicate the existing tree's paths in full. If duplication reveals one shared concept, collapse the subjects into one tree and let one generic implementation serve both.

Every `then` adds information that its condition does not already imply. Reject tautological outcomes.

Causal nesting is mandatory: a `when` trigger made possible only by a preceding `then` outcome is not a sibling — it is a child of that outcome.

### 6. Decompose from Consumer Pressure

Capture the outermost consumer tree first: a Journey tree for a new user arc, or a System tree for a capability under an existing journey. Write only the outermost tree up front. A failing journey or functional test creates pressure for System and inner-layer trees.

Plan the possible Journey → System → inner-layer movement without designing those inner trees. The higher-level tree and failing test create the demand for the next inner unit. Designing inner-layer trees from speculation is a YAGNI failure.

Write one tree per behavioural unit with substantive observable behaviour at its natural layer: Domain, Use-case, Adapter, or Port. Component and Use-case carry exhaustive single-capability coverage. System and Journey validate the same surfaces with real everything, selectively.

Trivial value objects, single-port delegation, and thin adapters without adapter-specific behaviour do not earn trees. Only substantive rules, non-trivial orchestration, non-trivial translation, and adapter-specific behaviour beyond the port contract earn separate inner trees.

### 7. Model Outbound Capabilities

When a side effect is identified, define an outbound port named for the capability, not technology. Ship the port in two flavours: an in-memory adapter and a real adapter. Write one shared contract suite for the port; both adapters must pass the shared contract suite.

System tests do not lean on the in-memory twin. They wire real driven adapters and exercise real infrastructure. Use-case tests use the in-memory twin; System tests and production wire real adapters.

### 8. Handle Cross-Cutting and Pure Behaviour

Cross-cutting System trees capture app-level policies that span slices. For a pure library, write a System tree only for a cross-function invariant observable across exported functions. If no cross-function invariant exists, omit System.

### 9. Let Tests Reveal the Layers

TDD turns the current tree into a failing consumer test. Its failure reveals the next missing behaviour or boundary.

When that failure exposes an inner unit:

1. Add the inner unit's tree.
2. Write its failing test at its own interface.
3. Follow that failure inward until the behaviour reaches the layer where it naturally lives.
4. Implement only after that native failing test exists.
5. Make the tests pass upward through each consuming layer.

Introduce only enough real structure to expose the next meaningful failure. Do not add placeholder production behaviour to satisfy an outer test.

The relevant test kinds are:

- Journey: broad, production-like test of a curated user arc across capabilities, with external services replaced by test doubles only if unavoidable.
- System: deep, production-like test of one capability through the whole app.
- Component: deep in-process test of one capability through the whole app, with external services replaced by test doubles.
- Adapter: test of one concrete boundary implementation against the real boundary it adapts.
- Port contract: tests for an application interface; each implementation must pass those tests.
- Unit: test of one public surface on one subject; every dependency outside the subject is mocked.

Domain and Use-case trees describe Unit tests at their respective hexagonal positions. Port trees describe Port-contract tests.

When a use-case needs an outbound capability, follow the outbound-port rules above.

## Finish

Leave `TEST_TREES.md` with the coherent contract that best reflects operator intention. Present the completed trees to the user for alignment and suggest running `sync`. Report what changed. Implementation proceeds through TDD.

Every tree's first line is `<Layer>: <Subject> (<coverage>)`. Without the layer prefix, readers and sync cannot detect duplication across layers.
