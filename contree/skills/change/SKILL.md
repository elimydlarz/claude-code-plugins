---
name: change
description: "Set expected behaviour by writing or modifying test trees before code changes. TRIGGER when: the user describes a feature, capability, behaviour change, removal, or modification they want — even loosely (e.g. 'I want X', 'let's add Y', 'can we make it do Z', 'change how X works', 'remove this behaviour')."
---

# Change

Turn a requested behaviour change into a coherent edit to `TEST_TREES.md` that faithfully expresses operator intention.

Change owns trees. TDD owns tests and implementation.

## Process

### 1. Inspect Reality

Read the relevant mental model, trees, tests, and source before editing the contract.

If trees and implementation already disagree in the affected area, reconcile that drift so the edited tree describes the intended post-change reality. Surface only consequential conflicts that cannot be resolved from the project.

### 2. Identify the Consumer

Identify:

- who or what observes the behaviour
- the interface through which it is observed
- the inputs or triggers
- the outcomes and side effects
- prevented effects and meaningful errors

Describe outer interfaces in the consumer's vocabulary. Describe an inner unit using its own public inputs, outputs, and errors, but only when an existing consumer has forced that unit into existence.

Pure functions are consumer-driven too: they exist because a caller needs to observe their result or error.

### 3. Reflect Operator Intention

Make the tree edit that most faithfully captures what the operator intends, including observable consequences discovered while tracing the change through the system.

- Modify every existing path affected by the intended behaviour.
- Follow the change through related trees, tests, and source to discover changed outcomes, side effects, prevented behaviour, and invariants.
- Make complementary tree adjustments wherever those consequences alter the contract.
- Add one tree for each new behavioural unit.
- Remove paths that no longer describe supported behaviour.
- Do not design inner trees before a failing consumer test reveals their need.

For a pure library, write the tree at the exported interface where the behaviour is consumed. Capture an invariant spanning slices as a System tree named for the policy.

### 4. Format the Tree

Every tree begins:

```text
<Layer>: <Subject> (<coverage>)
```

Layers are `Journey`, `System`, `Component`, `Adapter`, `Use-case`, `Domain`, and `Port`.

The subject is the behaviour-bearing thing observed at that layer.

One tree maps to exactly one test file. Its paths map verbatim to that file's `describe`/`it` hierarchy.

Coverage is recorded as semicolon-separated labelled paths:

```text
Domain: Money (src: src/money.ts; domain: src/money.domain.test.ts)
System: save-score (system: none)
```

Labels are `src`, `domain`, `use-case`, `adapter`, `component`, `system`, and `journey`.

Use `none` when coverage is expected but missing. Omit categories that do not apply. Coverage may be attached to a subtree when a distinct file owns that behaviour.

Treat dishonest coverage or file boundaries as design feedback and resolve the mismatch.

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

Each path must:

- describe observable behaviour, including side effects
- state principles rather than enumerate examples
- add information rather than restate its condition
- include meaningful negative behaviour
- stand alone without references such as "see above"
- use consumer vocabulary rather than implementation details

When behaviour is described as "just like" existing behaviour, write the paths in full. If duplication reveals one shared concept, collapse the subjects into one tree and let one generic implementation serve both.

### 6. Let Tests Reveal the Layers

TDD turns the current tree into a failing consumer test. Its failure reveals the next missing behaviour or boundary.

When that failure exposes an inner unit:

1. Add the inner unit's tree.
2. Write its failing test at its own interface.
3. Follow that failure inward until the behaviour reaches the layer where it naturally lives.
4. Implement only after that native failing test exists.
5. Make the tests pass upward through each consuming layer.

Introduce only enough real structure to expose the next meaningful failure. Do not add placeholder production behaviour to satisfy an outer test.

The relevant test kinds are:

- **Journey** — broad, production-like test of a curated user arc across capabilities.
- **System** — deep, production-like test of one capability through the whole app.
- **Component** — deep in-process test of one capability through the whole app, with external services replaced by test doubles.
- **Adapter** — test of one concrete boundary implementation against the real boundary it adapts: HTTP, CLI, database, filesystem, queue, third-party API, and similar boundaries.
- **Port contract** — test of an application interface such as a repository, gateway, or store; each implementation of that interface passes the contract.
- **Unit** — test of one public surface on one subject; every dependency outside the subject is mocked.

Domain and Use-case trees describe Unit tests at their respective hexagonal positions. Port trees describe Port-contract tests.

Tests at different layers intentionally overlap while asserting different seams. Higher-level coverage does not replace the native test for behaviour it consumes.

Only substantive rules, orchestration, translation, and adapter-specific behaviour earn separate inner trees. Trivial forwarding does not.

When a use-case needs an outbound capability, define a capability-named port with an in-memory twin and a real adapter. Both pass the same Port contract.

## Finish

Leave `TEST_TREES.md` with the coherent contract that best reflects operator intention and report what changed. Implementation proceeds through TDD.
