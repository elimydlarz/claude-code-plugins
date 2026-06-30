---
name: change
description: "Set expected behaviour by writing or modifying test trees — the contract that says what the system should do before any code exists. TRIGGER when: the user describes a feature, capability, or behaviour change they want — even loosely (e.g. 'I want X', 'let's add Y', 'can we make it do Z', 'change how X works', 'I need to modify', 'remove this behaviour'). Trigger before any code is discussed or written."
---

# Change

Sets expected behaviour before code exists. Talks through a behaviour change with the user and writes it into `TEST_TREES.md` at the project root — making intent explicit and agreed before implementation begins.

## When to Use

- Adding a new capability or feature
- Modifying existing behaviour
- Removing a capability
- When the user describes what they want built or changed
- Before implementation — trees first, code second

## Process

### 1. Understand the Change

What behaviour is being added, modified, or removed? Talk it through with the user. Clarify scope and boundaries before touching any trees.

**Read the actual tests and source of the area being changed before drafting the tree edit.** The existing tree is a claim about what the code does; the code is what it actually does. If they disagree, a tree edit grounded only in the tree will compound the drift. Reconcile pre-existing tree-code drift in the working area as part of the change — the new tree must be coherent with post-change reality, not with a stale snapshot. If reconciliation is non-trivial, surface it to the user and decide together whether to fold it in or split it out before proceeding.

### 2. Identify the Consumer

Who or what consumes this behaviour? A user? An API client? Another module? The consumer's perspective is where you start — not the internals.

Use the consumer's vocabulary. If the consumer says "register", the tree says "registers" — not "calls POST /api/users".

### 3. Write or Modify the Trees

**Adding a new capability:**

**Start outside-in with the outermost tree the change needs — and only that one.**

- A brand-new user-visible flow starts as a **Journey tree**: the expansive, max-realism arc that spans multiple capabilities and the contexts they touch, passes through representative error paths (not every one — generic error handling is proven at lower layers), and eventually succeeds. This is the outside-in entry point and the contract a real, max-realism functional test holds the whole system to — real driving and driven adapters, real infrastructure, real boundaries. The journey is **curated, never exhaustive**: keep it runnable in under 5 minutes, trimmed to the highest-impact (most damaging if broken) and most-recent (most likely to break) steps; re-evaluate it whenever you touch it, and do not add a journey step for every capability — the lower layers carry the rest.
- A capability within an existing flow is captured as a **System tree** — the whole app wired with real driven adapters for that one capability — hung beneath the Journey that traverses it. Extend the existing Journey tree with the new step rather than writing a second journey.

Inner trees (System where the journey has not yet pulled it in, Use-case, Domain, Port, Adapter) get added *as `tdd` discovers them* by pulling the failing journey/functional test through the layers — derived from what the outer test demands, not designed ahead of time. The exception is the pure-library case below (no slice), where Domain/Port trees may stand alone. Naming an inner tree before its need has surfaced is YAGNI failure: it commits to a decomposition the implementation hasn't asked for.

Name the tree — **always `<Layer>: <Subject>`** where `<Layer>` is one of `Journey`, `System`, `Component`, `Adapter`, `Use-case`, `Domain`, `Port`, and `<Subject>` is a short noun phrase naming the unit under test. Without the layer prefix, readers and `sync` cannot tell what level a tree exercises and cannot detect duplication across layers. Without a clear subject, the tree's tests are unreadable.

**One tree reifies exactly one test file.** If a capability exposes multiple behavioural units (e.g. a module with `generate` AND `isValid`, each testable independently), write **one tree per unit**, not one tree grouping them under a shared header. Grouping destroys the one-tree-one-file invariant and forces the TDD skill to fabricate ambiguous test structure.

Write paths using EARS patterns (see EARS Patterns below) to describe the capability's operating principles:

```
<Layer>: <Subject>
  then <ubiquitous outcome>
  while <precondition>
    then <outcome>
  when <trigger>
    then <outcome>
    and <outcome>
  if <error condition>
    then <recovery outcome>
```

Add as a new `###` subsection in `TEST_TREES.md`.

**Modifying existing behaviour:**

Find the existing tree. Add, change, or remove `when/then` paths to reflect the new behaviour. Don't rewrite paths that aren't changing.

**Removing a capability:**

Remove the tree from `TEST_TREES.md`. Confirm with the user first.

**Name the tree's coverage per category.**

Every tree must name its coverage in parentheses at the end of the tree-name line as semicolon-separated labelled pairs. Each label names one kind of test by its layer — no aggregating or aliasing. The seven categories are:

- `src` — implementation file (the source the tree's behaviour lives in)
- `domain` — pure-core test, no collaborators (Domain layer; or a pure-logic structural check where the tree's "implementation" is prose)
- `use-case` — orchestration test over in-memory adapters (Use-case layer)
- `adapter` — one adapter against its contract with real infra (Adapter layer; driven adapter against real infra, port contract against a real implementation)
- `component` — whole-app test of a single capability with real adapters and externals doubled at the edge — an in-memory database and stubbed outbound HTTP (Component layer)
- `system` — whole-app test of a single capability with real infrastructure (System layer)
- `journey` — expansive end-to-end test of the multi-capability user arc (Journey layer)

```
Domain: Money (src: src/features/money/domain/money.ts; domain: src/features/money/domain/money.domain.test.ts)
  add
    when called with another Money of the same currency
      then the sum's amount is the sum of the two amounts
```

A System tree with no 1:1 source file omits `src`:

```
System: save-score (use-case: src/features/score/application/save-score.use-case.test.ts; system: test/system/save-score.system.test.ts)
  when a user submits a valid score
    then the score is persisted
```

**Gaps are declared explicitly.** A category that is expected but not yet covered uses the value `none` so the gap is visible to readers and to `sync`. A category that is genuinely not applicable to the tree is omitted entirely — no placeholder needed.

Paths may also appear on a subtree or `then` line when the behaviour at that node is implemented by a distinct file — rare in practice, but the rule applies wherever a 1:1 file mapping holds.

If naming a (sub)tree's paths reveals an awkward shape — the tree doesn't sit naturally with where the code lives, or one tree spans multiple source files — treat that as design feedback: reshape the tree or the implementation until the paths fit. Do not strip the paths to hide the mismatch.

### 4. Decompose Across Layers and Positions

A Journey tree describes a user-visible arc across capabilities. Beneath it, a System tree describes each slice's consumer-visible behaviour, and below that sits a set of smaller trees — one per behavioural unit the slice produces. Each tree reifies one test file at one test layer.

**The test layers, outermost-in:**

```
  [ Driving Adapter ]  ←→  [ Port ]  ←→  [ Use-case ]  ←→  [ Port ]  ←→  [ Driven Adapter ]
     (HTTP / CLI)             (iface)      (orchestration)   (iface)       (Postgres / Stripe / FS)
                                                 ↕
                                           [ Domain ]
                                    (entities, value objects,
                                     domain services, rules)
```

| Layer       | Seam under test                  | Collaborators                                           | Speed     | File convention                     |
| ----------- | -------------------------------- | ------------------------------------------------------- | --------- | ----------------------------------- |
| Journey     | the whole app across a multi-capability user arc | **real driving + driven adapters, real infrastructure, real boundaries** — the expansive max-realism arc; spans capabilities and contexts, passes representative error paths, eventually succeeds | slowest | `*.journey.test.*` in `test/journey/` |
| System      | the whole wired app for one capability | **real infrastructure** — the same single-capability surface a Component test covers, validated against real everything; selective, not exhaustive | slow | `*.system.test.*` in `test/system/` |
| Component   | the whole wired app for one capability | **real driving + driven adapters; externals doubled only at the edge — an in-memory database and stubbed outbound HTTP** — runs in-process, needs no external services; carries exhaustive single-capability coverage | medium | `*.component.test.*` in `test/component/` |
| Adapter     | one adapter against its contract | driving: mocked use-case. driven: real infrastructure.  | mixed     | `*.adapter.test.*`                  |
| Use-case    | orchestration + port boundaries  | in-memory adapters (real implementations of the ports)  | fast      | `*.use-case.test.*`                 |
| Domain      | the pure core                    | none — no fakes, no mocks, no async                     | instant   | `*.domain.test.*`                   |

Journey and System are both real functional testing — Journey spans the user arc across capabilities, System pins one capability. When breadth at max realism is unaffordable, lean on the journey and push combinatorial detail down to inner layers — never a broad in-memory-wired System suite. The hex layers below are named for the seam under test, not infrastructure presence. Classic "unit/integration/functional" conflates pure Domain with mocked Use-case and overloads "integration" — seams give sharper targets.

**Use-case is to Component as Journey is to System** — two orientations (behaviour-oriented: Use-case, Journey; system-oriented: Component, System) across two realism tiers. The cheap tier doubles what it can (in-memory twins; edge doubles) and is always written and exhaustive; the real tier integrates everything affordable and is selective. Use-case and Component carry exhaustive coverage; System and Journey validate the same surfaces with real everything, selectively.

**Hex positions** — the locations in the codebase where code sits:

- **Domain** — entities, value objects, aggregates, domain services. No framework, no I/O, no async. Data in, data out.
- **Use-case (application)** — orchestrates a single consumer-visible behaviour. Receives outbound ports as constructor args. Returns plain data, never adapter types.
- **Driving adapter** — translates a transport (HTTP, CLI, queue, cron) into use-case input and the result back.
- **Outbound port** — interface the use-case depends on (repository, gateway, clock, logger). Lives next to the use-case in `application/ports/`.
- **Driven adapter** — concrete implementation of an outbound port. Ships with an in-memory twin (for Use-case and System tests) plus the real one (for production and Adapter tests).

**Decomposition rules:**

- The outermost tree describes the **journey** — a Journey tree named for the user-visible arc (`checkout`, `onboarding`). It drives the journey test and is the outside-in entry point; one journey traverses several slices and the contexts they touch. Keep it curated and runnable in under 5 minutes (highest-impact + most-recent steps) — there is rarely more than one or a few journeys, and never one per capability.
- Each **slice** the journey traverses is a System tree named for the consumer-visible capability (`save-score`, `cancel-order`). It drives that capability's System test.
- **Pure libraries (no vertical slice).** A library with only exported functions and no driving adapter, no use-case, and no driven port has no slice in the usual sense. Still write a System tree if any cross-function invariant is observable (e.g. `ShortCode` — *when `generate()` produces a code, then `isValid()` accepts it*). If no cross-function invariant exists, omit System altogether and document the omission — but never leave a System test file without a corresponding tree.
- Below the slice, write a **separate tree** for each behavioural unit that has observable behaviour someone could change silently:
  - A **Domain tree** per domain object or service with substantive rules (`Money`, `SessionToken`). Trivial value objects don't earn a tree — they're implicit in the use-case.
  - A **Use-case tree** per use-case with non-trivial orchestration (`save-score-use-case`). A use-case that just delegates to a single port doesn't earn a tree.
  - A **Driving-adapter tree** per adapter with non-trivial translation (`score-http-handler`). Thin adapters don't earn a tree.
  - A **Port contract tree** per outbound port (`ScoreRepository`, `AuditLog`). The tree is reified by a shared contract suite (see `skills/tdd/SKILL.md`) that both the in-memory and real adapters must pass. Name ports for capability, not technology (`OrderRepository`, not `PostgresClient`).
  - A **Driven-adapter tree** per real driven adapter when it has adapter-specific behaviour beyond the port contract (`ScoreRepository-Postgres` for timeout/retry/schema; the port contract covers the rest).
- **One tree, one test file.** Each tree's `describe`/`it` hierarchy mirrors the tree verbatim.
- **Cross-cutting System trees** — for app-level invariants that aren't per-slice (auth enforcement, rate limiting, error envelope), write a System tree named for the policy.

**Tree naming heuristic** — every tree name is `<Layer>: <Subject>`. Pick the subject with observable behaviour at that layer:

| Layer    | Subject                                  | Example                                                       |
| -------- | ---------------------------------------- | ------------------------------------------------------------- |
| Journey  | user-visible arc across capabilities     | `Journey: checkout`, `Journey: onboarding`                    |
| System   | capability/slice or cross-cutting policy | `System: save-score`, `System: auth-enforcement`              |
| Adapter  | adapter being exercised                  | `Adapter: score-http-handler`, `Adapter: ScoreRepository-Postgres` |
| Use-case | the use-case                             | `Use-case: save-score-use-case`                               |
| Port     | port interface (shared contract)         | `Port: ScoreRepository`, `Port: AuditLog`                     |
| Domain   | domain object or service                 | `Domain: Money`, `Domain: SessionToken`                       |

**Tree shape per layer** — the naming heuristic names the tree; the shape rule organises its paths.

| Layer          | Shape            | Top-level nodes                                                                                 |
| -------------- | ---------------- | ----------------------------------------------------------------------------------------------- |
| Journey        | Consumer-shaped  | Steps of the user arc across capabilities, in sequence — eventually succeeding. Consumer vocabulary; representative paths, not every error. |
| System         | Consumer-shaped  | Consumer-visible events on the slice. Consumer vocabulary; principles, not cases.               |
| Adapter        | Protocol-shaped  | The adapter's exposed operations (HTTP routes, CLI commands, queue topics, real-infra concerns). |
| Use-case       | Code-shaped      | The use-case's entry point (usually `execute` or the function name). Paths = observable branches. |
| Domain         | Code-shaped      | The unit's exported functions/methods. Paths = observable branches.                             |
| Port contract  | Method-shaped    | The port's methods. Paths = behaviours the contract requires of every implementation.           |

At Domain, Use-case, and Port-contract, TDD + YAGNI means no branch without a path and no path without a branch — the tree maps onto the code's methods and branches. At Journey, System, and Adapter, the tree describes observable behaviour at the seam, not the internal branches that produce it.

A Domain tree is shaped like its class/module:

```
Domain: Money (src: src/features/money/domain/money.ts; domain: src/features/money/domain/money.domain.test.ts)
  add
    when called with another Money of the same currency
      then the sum's amount is the sum of the two amounts
      and the currency is preserved
    if called with another Money of a different currency
      then CurrencyMismatch is thrown
  multiply
    when called with a positive factor
      then the amount is multiplied by the factor
    if called with a negative factor
      then NegativeMultiplier is thrown
```

The test file's describe/it hierarchy mirrors this verbatim.

**The in-memory adapter pattern**

For each outbound port, ship two adapters that both satisfy the port contract:

```
OrderRepository (port interface)
├── PostgresOrderRepository    ← real, used in production and in System and driven-adapter tests
└── InMemoryOrderRepository    ← real, used in Use-case tests
```

The in-memory adapter is not a mock. It's a real implementation: stores data in a map, enforces the same invariants (unique IDs, referential rules, ordering guarantees) that the real adapter does. The composition root swaps it in at test time by pointing at a different wiring.

What this buys:

- Use-case tests run in milliseconds against *real application behaviour* — so the Use-case layer can carry combinatorial branch coverage cheaply.
- The real adapter's job shrinks to "adapt Postgres to the port" — driven-adapter tests cover only adapter-local behaviour beyond the shared contract.

System tests do NOT lean on the in-memory adapter. They wire real driven adapters and exercise real infrastructure — that's the point of the System layer. The in-memory twin exists to serve Use-case tests, not to dilute System tests into slow Use-case tests with extra ceremony.

**The shared port contract suite**

In-memory substitution is only sound if both adapters really do satisfy the same contract. Enforce this with a shared contract suite: one test suite, imported by both adapter test files.

```ts
// src/features/score/application/ports/score-repository.contract.ts
export function scoreRepositoryContract(makeRepo: () => ScoreRepository) {
  describe('ScoreRepository', () => {
    describe('save', () => {
      describe('when called with a score', () => {
        it('makes the score retrievable by its id', async () => {
          const repo = makeRepo()
          await repo.save(someScore)
          expect(await repo.findById(someScore.id)).toEqual(someScore)
        })
      })
      describe('if called twice with the same score id', () => {
        it('rejects the second call without side effects', async () => { /* ... */ })
      })
    })
  })
}
```

```ts
// src/features/score/adapters/outbound/in-memory/in-memory-score-repository.adapter.test.ts
import { scoreRepositoryContract } from '../../../application/ports/score-repository.contract'
scoreRepositoryContract(() => new InMemoryScoreRepository())
```

```ts
// src/features/score/adapters/outbound/postgres/postgres-score-repository.adapter.test.ts
import { scoreRepositoryContract } from '../../../application/ports/score-repository.contract'
scoreRepositoryContract(() => new PostgresScoreRepository(testDb))
// Plus Postgres-specific tests: timeouts, schema, constraint violations.
```

The contract suite IS the port-contract tree (`ScoreRepository`). Both adapter tests run the shared suite. The real adapter's test file *also* has tests for behaviour that only exists at its seam (timeouts, retries, constraint violations) — those live in the same `*.adapter.test.*` file but outside the shared suite.

The tree in `TEST_TREES.md`:

```
Port: ScoreRepository (src: src/features/score/application/ports/score-repository.ts; adapter: src/features/score/adapters/outbound/postgres/postgres-score-repository.adapter.test.ts)
  save
    when called with a score
      then the score is retrievable by its id
    if called twice with the same score id
      then the second call is rejected without side effects
```

**Feature-first module layout** — use this directory shape when adding or touching a capability:

```
src/features/<name>/
  domain/              # entities, value objects, domain services (+ .domain.test.*)
  application/
    ports/             # outbound port interfaces (+ .contract.ts shared suites)
    use-cases/         # orchestration (+ .use-case.test.*)
  adapters/
    inbound/           # http, cli, queue, cron (+ .adapter.test.*)
    outbound/
      in-memory/       # in-memory implementations of outbound ports
      <real>/          # real implementations (postgres, stripe, s3) (+ .adapter.test.*)
  composition/         # explicit wiring; points at real or in-memory adapters per layer
```

The **composition root** is the only place that imports concrete adapters and wires them into use-cases. Nothing else should. Use-case and System tests wire in-memory adapters through it; production wires real adapters.

### 5. Present for Alignment

Share the trees with the user before moving to implementation. The trees are the contract — get agreement before building.

Once aligned, suggest the user runs `sync` to audit completeness and implement gaps.

## Tree Format Rules

- **Use EARS patterns** — choose the right keyword for each requirement (see EARS Patterns below). Don't force everything into `when/then`.
- **`then` describes outcomes, including side effects** — what the consumer observes, what changes, what's produced, what's prevented, what's written externally (files, network, logs, state), what's cleaned up. A side effect that another invocation, hook, process, or operator could detect is behaviour and belongs in the tree.
- **Every `then` must assert something the `when` clause does not already imply** — if a `then` merely restates the condition, it's a tautology and adds no value. "when created / then it is created" tests nothing. "when created with default / then value is zero" asserts a concrete outcome.
- **Include the negative** — use `if/then` for error cases and unwanted behaviour. Absence of behaviour is part of the specification.
- **Describe principles, not cases** — applies at Journey, System, and Adapter layers: "when the input is invalid" not "when the input is empty / when the input is null / when the input is too long". At Domain, Use-case, and Port-contract, each observable branch *is* a principle; enumerate them all.
- **Use the consumer's vocabulary** — applies at Journey, System, and Adapter layers: describe what the consumer sees, not implementation internals. At Domain, Use-case, and Port-contract, speak in the unit's own vocabulary (its function names, its types, its errors).
- **Tree ≡ describe/it hierarchy verbatim** — every path in the tree appears as a describe/it in the test file; every describe/it in the test file appears as a path in the tree. This is the framework-agnostic contract; `sync` compares these two directly.
- **Name the layer and subject** — every tree's first line is `<Layer>: <Subject>` (e.g. `Domain: Money`, `System: save-score`). The layer disambiguates trees that share a subject across layers; the subject is what is being tested. Without both, duplication can't be spotted and the test's purpose isn't legible.
- **Every leaf stands alone** — a `then` clause states its assertion inline. No cross-leaf references: phrases like "see above", "as before", or "the existing X branch holds" are forbidden. If two leaves would say the same thing, write both — duplication is the diagnostic signal that surfaces shared concepts; suppressing it hides design problems.
- **"Just like X" duplicates, then maybe collapses** — when the user describes new behaviour as "just like" or "the same as" an existing tree's behaviour, duplicate that tree's paths under the new subject in full rather than cross-referencing. If the duplication reveals the two subjects are the same concept, collapse them under one tree named for the shared concept and make the implementation generic to serve both. Duplicate first; collapse only when duplication itself names the shared concept.

## Examples

**Good** — a Journey tree: the multi-capability arc, passing a representative error, eventually succeeding:
```
Journey: checkout
  when a shopper adds an item to the cart
    then the cart shows the item and a running total
  when they enter an invalid shipping address
    then the address is rejected with a correction prompt
  when they enter a valid address and pay
    then payment is captured
    and an order confirmation is shown
    and a receipt email is sent
```

A Journey spans capabilities (cart, address, payment, notification) and the contexts they establish; it walks one representative error (invalid address) and lets the lower layers exhaust the rest; it ends in success.

**Good** — uses EARS patterns to match each requirement's nature:
```
System: media-player
  then supports mp3 and wav formats
  while playing
    when pause is pressed
      then playback pauses at current position
    when track ends
      then the next track starts automatically
  when a track is loaded
    then playback begins from the start
  if the file is corrupt
    then playback is rejected with an error message
  where bluetooth is available
    then audio can be routed to a bluetooth device
```

**Bad** — missing layer and subject (just a bare capability slug):
```
media-player
  when a track is loaded
    then playback begins from the start
```

**Good** — names layer and subject so duplication is detectable and purpose is legible:
```
System: media-player
  when a track is loaded
    then playback begins from the start
```

**Bad** — enumerates cases:
```
System: media-player
  when file is "song.mp3"
    then song.mp3 plays
  when file is "track.wav"
    then track.wav plays
```

**Good** — states the principle once:
```
System: media-player
  then supports mp3 and wav formats
  when a track is loaded
    then playback begins from the start
```

**Bad** — tautological (then restates the when, so the path asserts nothing):
```
System: media-player
  when a track is loaded
    then a track is loaded
  when playback is paused
    then it pauses
```

**Good** — then asserts an outcome the when does not imply:
```
System: media-player
  when a track is loaded
    then playback begins from the start
  when playback is paused
    then the current position is retained for resume
```

**Bad** — flat siblings for causally dependent behaviour:
```
Use-case: auth
  when token is invalid
    then refresh is attempted
  when refresh fails
    then user is logged out
```

**Good** — causal nesting (refresh failure depends on refresh being attempted):
```
Use-case: auth
  when token is invalid
    then refresh is attempted
      when refresh fails
        then user is logged out
```

**Bad** — uses implementation language:
```
System: media-player
  when AudioContext.decodeAudioData resolves
    then the Float32Array buffer is assigned to the source node
```

**Good** — uses consumer vocabulary:
```
System: media-player
  when a track is loaded
    then playback begins from the start
```

## EARS Patterns

Test trees use EARS (Easy Approach to Requirements Syntax) to choose the right keyword for each requirement. Match the pattern to the requirement's nature — don't force everything into `when/then`.

**Ubiquitous** — always true, no condition:
```
then <outcome>
```

**State-driven** — active while a condition holds:
```
while <precondition>
  then <outcome>
```

**Event-driven** — response to a trigger:
```
when <trigger>
  then <outcome>
```

**Optional feature** — applies only when a feature is present:
```
where <feature>
  then <outcome>
```

**Unwanted behaviour** — response to error or undesired situation:
```
if <condition>
  then <outcome>
```

**Complex** — state + event combined:
```
while <precondition>
  when <trigger>
    then <outcome>
```

**Causal nesting** — when a trigger can only occur as a consequence of a prior outcome, nest it under that outcome:
```
when <trigger>
  then <outcome>
    when <consequence of outcome>
      then <next outcome>
```

A `when` that depends on a preceding `then` is not a sibling — it is a child. If "refresh fails" can only happen because "refresh was attempted", nest it under the `then` that attempts the refresh.

Choose the pattern that fits: a system constraint is ubiquitous; a precondition that must hold is state-driven; a discrete trigger is event-driven; an error case is unwanted behaviour; a feature flag is optional. Combine when needed. Nest when one behaviour depends on another's outcome.
