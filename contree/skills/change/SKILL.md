---
name: change
description: "Set expected behaviour by writing or modifying test trees before code changes. TRIGGER when: the user describes a feature, capability, behaviour change, removal, or modification they want — even loosely (e.g. 'I want X', 'let's add Y', 'can we make it do Z', 'change how X works', 'remove this behaviour')."
---

# Change

Defines expected behaviour as test trees before implementation begins.

The change skill is responsible for understanding the requested behaviour, choosing the right outer layer, and writing clear trees in `TEST_TREES.md`. It does not write test files or implementation examples. The `tdd` skill owns turning trees into tests and code.

## When to Use

- Adding a new capability or feature
- Modifying existing behaviour
- Removing a capability
- Debugging a bug that reveals a missing behaviour contract
- Any time expected behaviour needs to be made explicit before implementation

## Outcome

A completed change pass leaves `TEST_TREES.md` with the smallest tree edit that accurately describes the requested behaviour from the right consumer perspective.

## Process

### 1. Understand the Change

Identify the behaviour being added, modified, or removed. Discuss the change with the user before modifying trees.

Read the actual tests and source of the area being changed before drafting the tree edit. The tree is a claim about the system; the implementation is the current reality. If they disagree in the area being changed, reconcile pre-existing tree-code drift as part of the change so the new tree is coherent with post-change reality. If reconciliation is non-trivial, surface it before continuing.

Clarify:

- what observable behaviour changes
- who or what observes it
- what side effects are produced or prevented
- what errors or unwanted behaviours matter
- whether this belongs to an existing tree or a new tree

### 2. Identify the Consumer

Start from the consumer of the behaviour.

Outside-in means a consumer is created before the thing it consumes is implemented. The higher-level tree and failing test create the demand for the next inner unit. Only then do we write the lower-layer tree that describes what that consumer needs from the unit.

At outer layers, the consumer is usually a person, API client, CLI user, hook caller, browser, queue producer, or external system.

At inner layers, the consumer is the next outer layer that forced the unit into existence. A pure function is still consumer-driven: it is introduced only because a use-case, domain service, or other caller needs to invoke it and observe its result or error.

Use consumer vocabulary. Do not describe implementation details at Journey, System, Component, or Adapter level.

### 3. Choose the Outermost Tree

Start outside-in with the outermost tree the change needs, and only that one.

If the change affects a user-visible arc across capabilities, start with a Journey tree.

If the change affects one capability, start with a System tree.

If the change is only observable inside an existing capability and no outer tree is missing, update the tree at the layer where the behaviour is observed by its consumer.

Do not pre-design inner trees. Inner Use-case, Domain, Port, and Adapter trees are added by `tdd` when a failing journey/functional test pulls the need into view. Naming an inner tree before its need has surfaced is speculation and YAGNI failure.

Pure libraries are the exception. If a library has no driving adapter, no use-case, and no driven port, write the tree at the layer where its exported behaviour is consumed. If multiple exported functions form an observable invariant together, a System tree may describe that invariant, such as `ShortCode` where `generate()` produces a code that `isValid()` accepts. If no cross-function invariant exists, omit System altogether and document the omission rather than leaving a System test file without a corresponding tree.

### 4. Write or Modify the Tree

For a new capability, add a new tree under `### Functional Requirements`.

For existing behaviour, edit the existing tree. Change only affected paths. Do not rewrite paths that are not changing.

For removal, remove the tree or paths that no longer describe supported behaviour after user confirmation.

Every tree starts with:

```text
<Layer>: <Subject> (<coverage>)
```

`<Layer>` is one of:

- `Journey`
- `System`
- `Component`
- `Adapter`
- `Use-case`
- `Domain`
- `Port`

`<Subject>` names the behaviour-bearing thing at that layer. The subject must have observable behaviour for its consumer.

One tree maps to exactly one test file. If two independent behavioural units are testable separately, they need two trees.

Write paths using EARS patterns:

```text
<Layer>: <Subject> (<coverage>)
  then <ubiquitous outcome>
  while <precondition>
    then <outcome>
  when <trigger>
    then <outcome>
    and <outcome>
  if <error condition>
    then <recovery outcome>
```

### 5. Name Coverage

Every tree names its coverage in parentheses as semicolon-separated labelled pairs.

Coverage labels are:

- `src` — implementation file
- `domain` — Domain test
- `use-case` — Use-case test
- `adapter` — Adapter test or Port contract implementation test
- `component` — Component test
- `system` — System test
- `journey` — Journey test

Use `none` when coverage is expected but not yet present.

Omit a category when it is genuinely not applicable.

Examples:

```text
Domain: Money (src: src/features/money/domain/money.ts; domain: src/features/money/domain/money.domain.test.ts)
```

```text
System: save-score (use-case: src/features/score/application/save-score.use-case.test.ts; system: test/system/save-score.system.test.ts)
```

```text
Journey: checkout (journey: none)
```

Paths may also appear on a subtree or `then` line when the behaviour at that node is implemented by a distinct file. If naming a tree's paths reveals a mismatch between the consumer need and the file boundaries, treat that as design feedback and adjust the tree or implementation until the mapping is honest.

### 6. Present for Alignment

Show the proposed tree change before implementation.

The tree is the behaviour contract. Once it is accepted, suggest running `sync` to check completeness and `tdd` to drive tests and implementation from it.

## Test Layers

Tests are layered outside-in, and every layer is consumer-driven.

Outside-in means a consumer is created before the thing it consumes is implemented. The higher-level tree and failing test create the demand for the next inner unit. Only then do we write the lower-layer tree that describes what that consumer needs from the unit.

| Layer | Consumer | Realism | Tree describes | Coverage role |
| --- | --- | --- | --- | --- |
| Journey | User or operator crossing capabilities | Real driving and driven adapters, real infrastructure, real boundaries | The user-visible arc and outcomes | Curated max-realism proof of the highest-impact user path |
| System | Consumer of one capability | Real driven adapters and real infrastructure | Capability behaviour and side effects | Selective real-everything proof of a capability |
| Component | In-process consumer of one capability | Real app wiring, with externals doubled at the edge | Capability behaviour with external services doubled | Exhaustive capability coverage without external services |
| Adapter | Boundary caller or boundary dependency | Real boundary for driven adapters; mocked use-case for driving adapters | Protocol inputs, outputs, errors, and boundary side effects | Boundary translation and adapter-local behaviour |
| Use-case | Driving adapter or higher application flow | In-memory implementations of outbound ports | Application behaviour needed by that consumer | Exhaustive orchestration coverage |
| Domain | Use-case or domain caller that forced the rule into existence | No collaborators, no I/O, no async | Inputs, outputs, errors, and pure rules needed by that caller | Exhaustive pure rule coverage |
| Port | Use-case needing an outbound capability | Shared contract run by every implementation | Guarantees every implementation must provide | Contract coverage for all implementations |

Journey trees describe the user-visible arc across capabilities. They are curated, not exhaustive. A Journey usually includes a representative error path and eventually succeeds. Keep journeys runnable in under 5 minutes and trimmed to the highest-impact and most-recent steps.

System trees describe one consumer-visible capability. They use consumer vocabulary and real infrastructure. System and Journey validate real-everything surfaces selectively because real-everything tests are expensive.

Component trees describe the same capability surface as System trees, but in-process with external services doubled only at the edge. Component and Use-case carry exhaustive capability and orchestration coverage cheaply.

Adapter trees describe the boundary protocol: HTTP routes, CLI commands, queue messages, filesystem behaviour, database adapter behaviour, or third-party API adapter behaviour.

Use-case trees describe the application behaviour needed by the driving adapter or higher application flow that forced the use-case into existence.

Domain trees describe the pure rules needed by the use-case or domain caller that forced the domain subject into existence. Pure functions are still consumer-driven. A pure function is introduced only because a use-case, domain service, or other caller needs to invoke it and observe its result or error.

Port trees describe the outbound capability guarantees needed by the use-case that depends on the port.

Use-case is to Component as Journey is to System: the cheap tier doubles what it can, the real tier integrates everything affordable. Use-case and Component are always written and exhaustive; System and Journey validate the same surfaces with real everything, selectively.

## Hexagonal Decomposition

Use hexagonal positions for code the tests pull into existence:

- **Domain** — entities, value objects, aggregates, domain services. No framework, no I/O, no async. Data in, data out.
- **Use-case** — orchestrates a single consumer-visible behaviour. Receives outbound ports as constructor args. Returns plain data, never adapter types.
- **Driving adapter** — translates a transport such as HTTP, CLI, queue, or cron into use-case input and the result back.
- **Outbound port** — interface the use-case depends on, named for capability, not technology.
- **Driven adapter** — concrete implementation of an outbound port. Ships with an in-memory twin plus the real adapter.

For each outbound port, ship two adapters that both satisfy the port contract:

```text
OrderRepository
├── PostgresOrderRepository
└── InMemoryOrderRepository
```

The in-memory adapter is not a mock. It is a real implementation that enforces the same invariants the real adapter does. Use-case tests use the in-memory twin. System tests do not lean on the in-memory twin; they wire real driven adapters and exercise real infrastructure.

The shared port contract suite is the Port tree. Both adapters must pass the shared suite. The real adapter's test file also carries adapter-local behaviour beyond the shared contract, such as timeouts, retries, schema, and constraint violations.

The composition root is the only place that imports concrete adapters and wires them into use-cases. Use-case tests wire in-memory adapters through it. System tests and production wire real adapters.

## Tree Format Rules

- **Use EARS patterns** — choose the right keyword for each requirement's nature. Do not force everything into `when/then`.
- **`then` describes outcomes, including side effects** — what the consumer observes, what changes, what is produced, what is prevented, what is written externally, what is cleaned up, and what a later invocation can detect.
- **Every `then` must assert something the parent condition does not already imply** — if a `then` merely restates the condition, it is tautological.
- **Include the negative** — use `if/then` for errors and unwanted behaviour. Absence of behaviour is part of the specification.
- **Describe principles, not cases** — applies at Journey, System, Component, and Adapter layers: `when the input is invalid`, not one path per invalid example.
- **Describe consumer-observed branches at inner layers** — at Use-case, Domain, and Port layers, describe what the outer consumer needs to observe from the unit it has forced into existence.
- **Tree equals describe/it hierarchy verbatim** — every path in the tree appears as a describe/it in the test file; every describe/it in the test file appears as a path in the tree.
- **Name the layer and subject** — every tree's first line is `<Layer>: <Subject>`. The layer disambiguates trees that share a subject across layers; the subject is what is being tested.
- **Every leaf stands alone** — a `then` clause states its assertion inline. Do not use cross-leaf references such as `see above`, `as before`, or `the existing X branch holds`.
- **"Just like X" duplicates, then maybe collapses** — when the user describes new behaviour as `just like` or `the same as` an existing tree's behaviour, duplicate that tree's paths under the new subject in full rather than cross-referencing. If the duplication reveals the two subjects are the same concept, collapse them under one tree named for the shared concept and make the implementation generic to serve both.
- **Causal triggers nest under their enabling outcome** — a `when` trigger that can only occur as a consequence of a prior `then` outcome is nested as a child of that outcome.

## EARS Patterns

Test trees use EARS patterns to choose the right keyword for each requirement. Match the pattern to the requirement's nature.

Ubiquitous:

```text
then <outcome>
```

State-driven:

```text
while <precondition>
  then <outcome>
```

Event-driven:

```text
when <trigger>
  then <outcome>
```

Optional feature:

```text
where <feature>
  then <outcome>
```

Unwanted behaviour:

```text
if <condition>
  then <outcome>
```

State plus event:

```text
while <precondition>
  when <trigger>
    then <outcome>
```

Causal nesting:

```text
when <trigger>
  then <outcome>
    when <next trigger made possible by the outcome>
      then <next outcome>
```

## Examples

Good Journey tree: multi-capability arc, representative error, eventual success.

```text
Journey: checkout (journey: test/journey/checkout.journey.test.ts)
  when a shopper adds an item to the cart
    then the cart shows the item and a running total
  when they enter an invalid shipping address
    then the address is rejected with a correction prompt
  when they enter a valid address and pay
    then payment is captured
    and an order confirmation is shown
    and a receipt email is sent
```

Bad tree: missing layer and subject.

```text
media-player
  when a track is loaded
    then playback begins from the start
```

Good tree: names the layer and subject.

```text
System: media-player (system: test/system/media-player.system.test.ts)
  when a track is loaded
    then playback begins from the start
```

Bad System tree: enumerates cases instead of stating the principle.

```text
System: media-player (system: test/system/media-player.system.test.ts)
  when file is "song.mp3"
    then song.mp3 plays
  when file is "track.wav"
    then track.wav plays
```

Good System tree: states the principle once.

```text
System: media-player (system: test/system/media-player.system.test.ts)
  then supports mp3 and wav formats
  when a track is loaded
    then playback begins from the start
```

Bad tree: tautological outcome.

```text
System: media-player (system: test/system/media-player.system.test.ts)
  when a track is loaded
    then a track is loaded
```

Good tree: outcome adds information.

```text
System: media-player (system: test/system/media-player.system.test.ts)
  when a track is loaded
    then playback begins from the start
```

Bad tree: flat siblings for causally dependent behaviour.

```text
Use-case: auth-session (use-case: src/features/auth/application/auth-session.use-case.test.ts)
  when token is invalid
    then refresh is attempted
  when refresh fails
    then user is logged out
```

Good tree: nests the dependent behaviour.

```text
Use-case: auth-session (use-case: src/features/auth/application/auth-session.use-case.test.ts)
  when token is invalid
    then refresh is attempted
      when refresh fails
        then user is logged out
```

Bad outer tree: implementation language.

```text
System: media-player (system: test/system/media-player.system.test.ts)
  when AudioContext.decodeAudioData resolves
    then the Float32Array buffer is assigned to the source node
```

Good outer tree: consumer language.

```text
System: media-player (system: test/system/media-player.system.test.ts)
  when a track is loaded
    then playback begins from the start
```
