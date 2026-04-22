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

### 2. Identify the Consumer

Who or what consumes this behaviour? A user? An API client? Another module? The consumer's perspective is where you start — not the internals.

Use the consumer's vocabulary. If the consumer says "register", the tree says "registers" — not "calls POST /api/users".

### 3. Write or Modify the Trees

**Adding a new capability:**

Name the tree — a short noun phrase describing what the system does. **One tree reifies exactly one test file.** If a capability exposes multiple behavioural units (e.g. a module with `generate` AND `isValid`, each testable independently), write **one tree per unit**, not one tree grouping them under a shared header. Grouping destroys the one-tree-one-file invariant and forces the TDD skill to fabricate ambiguous test structure.

Write paths using EARS patterns (see EARS Patterns below) to describe the capability's operating principles:

```
capability-name
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

### 4. Decompose Across Layers and Positions

A System tree describes a slice's consumer-visible behaviour. Below it sits a set of smaller trees — one per behavioural unit the slice produces. Each smaller tree reifies one test file at one test layer.

**The four test layers map to the hex seams:**

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
| Domain      | the pure core                    | none — no fakes, no mocks, no async                     | instant   | `*.domain.test.*`                   |
| Use-case    | orchestration + port boundaries  | in-memory adapters (real implementations of the ports)  | fast      | `*.use-case.test.*`                 |
| Adapter     | one adapter against its contract | driving: mocked use-case. driven: real infrastructure.  | mixed     | `*.adapter.test.*`                  |
| System      | the whole wired app              | in-memory driven adapters by default; real on demand    | slow      | `*.system.test.*` in `test/system/` |

Layers are named for the hex seam under test, not for infrastructure presence. Classic "unit/integration/functional" conflates pure Domain with mocked Use-case and overloads "integration" — seams give sharper targets.

**Hex positions** — the locations in the codebase where code sits:

- **Domain** — entities, value objects, aggregates, domain services. No framework, no I/O, no async. Data in, data out.
- **Use-case (application)** — orchestrates a single consumer-visible behaviour. Receives outbound ports as constructor args. Returns plain data, never adapter types.
- **Driving adapter** — translates a transport (HTTP, CLI, queue, cron) into use-case input and the result back.
- **Outbound port** — interface the use-case depends on (repository, gateway, clock, logger). Lives next to the use-case in `application/ports/`.
- **Driven adapter** — concrete implementation of an outbound port. Ships with an in-memory twin (for Use-case and System tests) plus the real one (for production and Adapter tests).

**Decomposition rules:**

- The top-level tree describes the **slice** — a System tree named for the consumer-visible capability (`save-score`, `cancel-order`). It drives the System test.
- **Pure libraries (no vertical slice).** A library with only exported functions and no driving adapter, no use-case, and no driven port has no slice in the usual sense. Still write a System tree if any cross-function invariant is observable (e.g. `ShortCode` — *when `generate()` produces a code, then `isValid()` accepts it*). If no cross-function invariant exists, omit System altogether and document the omission — but never leave a System test file without a corresponding tree.
- Below the slice, write a **separate tree** for each behavioural unit that has observable behaviour someone could change silently:
  - A **Domain tree** per domain object or service with substantive rules (`Money`, `SessionToken`). Trivial value objects don't earn a tree — they're implicit in the use-case.
  - A **Use-case tree** per use-case with non-trivial orchestration (`save-score-use-case`). A use-case that just delegates to a single port doesn't earn a tree.
  - A **Driving-adapter tree** per adapter with non-trivial translation (`score-http-handler`). Thin adapters don't earn a tree.
  - A **Port contract tree** per outbound port (`ScoreRepository`, `AuditLog`). The tree is reified by a shared contract suite (see `skills/tdd/SKILL.md`) that both the in-memory and real adapters must pass. Name ports for capability, not technology (`OrderRepository`, not `PostgresClient`).
  - A **Driven-adapter tree** per real driven adapter when it has adapter-specific behaviour beyond the port contract (`ScoreRepository-Postgres` for timeout/retry/schema; the port contract covers the rest).
- **One tree, one test file.** Each tree's `describe`/`it` hierarchy mirrors the tree verbatim.
- **Cross-cutting System trees** — for app-level invariants that aren't per-slice (auth enforcement, rate limiting, error envelope), write a System tree named for the policy.

**Tree naming heuristic** — name each tree for the subject with observable behaviour at its layer:

| Layer    | Subject                             | Example                                         |
| -------- | ----------------------------------- | ----------------------------------------------- |
| Domain   | domain object or service             | `Money`, `SessionToken`, `LeaderboardRanking`   |
| Use-case | the use-case                         | `save-score-use-case`                           |
| Port     | port interface (shared contract)     | `ScoreRepository`, `AuditLog`                   |
| Adapter  | adapter being exercised              | `score-http-handler`, `ScoreRepository-Postgres`|
| System   | capability/slice or cross-cutting policy | `save-score`, `auth-enforcement`            |

**Tree shape per layer** — the naming heuristic names the tree; the shape rule organises its paths.

| Layer          | Shape            | Top-level nodes                                                                                 |
| -------------- | ---------------- | ----------------------------------------------------------------------------------------------- |
| Domain         | Code-shaped      | The unit's exported functions/methods. Paths = observable branches.                             |
| Use-case       | Code-shaped      | The use-case's entry point (usually `execute` or the function name). Paths = observable branches. |
| Port contract  | Method-shaped    | The port's methods. Paths = behaviours the contract requires of every implementation.           |
| Adapter        | Protocol-shaped  | The adapter's exposed operations (HTTP routes, CLI commands, queue topics, real-infra concerns). |
| System         | Consumer-shaped  | Consumer-visible events on the slice. Consumer vocabulary; principles, not cases.               |

At Domain, Use-case, and Port-contract, TDD + YAGNI means no branch without a path and no path without a branch — the tree maps onto the code's methods and branches. At Adapter and System, the tree describes observable behaviour at the seam, not the internal branches that produce it.

A Domain tree is shaped like its class/module:

```
Money
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

This is the linchpin of the whole scheme. Without it, Use-case and System tests either get slow (real infra) or dishonest (mocks that don't match reality).

For each outbound port, ship two adapters that both satisfy the port contract:

```
OrderRepository (port interface)
├── PostgresOrderRepository    ← real, used in production and in driven-adapter tests
└── InMemoryOrderRepository    ← real, used in Use-case and System tests
```

The in-memory adapter is not a mock. It's a real implementation: stores data in a map, enforces the same invariants (unique IDs, referential rules, ordering guarantees) that the real adapter does. The composition root swaps it in at test time by pointing at a different wiring.

What this buys:

- Use-case tests run in milliseconds against *real application behaviour*.
- System tests run fast by default, covering the full vertical slice.
- The real adapter's job shrinks to "adapt Postgres to the port" — everything application-level is already covered by tests running against the in-memory adapter.

**The shared port contract suite**

In-memory substitution is only sound if both adapters really do satisfy the same contract. Enforce this with a shared contract suite: one test suite, imported by both adapter test files.

```ts
// src/features/score/application/ports/score-repository.contract.ts
export function scoreRepositoryContract(makeRepo: () => ScoreRepository) {
  describe('ScoreRepository', () => {
    describe('when save is called with a score', () => {
      it('is retrievable by its id', async () => {
        const repo = makeRepo()
        await repo.save(someScore)
        expect(await repo.findById(someScore.id)).toEqual(someScore)
      })
    })
    describe('if save is called twice with the same score id', () => {
      it('rejects the second call without side effects', async () => { /* ... */ })
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
ScoreRepository
  when save is called with a score
    then the score is retrievable by its id
  if save is called twice with the same score id
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
- **Describe principles, not cases** — "when the input is invalid" not "when the input is empty / when the input is null / when the input is too long".
- **Include the negative** — use `if/then` for error cases and unwanted behaviour. Absence of behaviour is part of the specification.
- **Use the consumer's vocabulary** — describe what the consumer sees, not implementation internals.

## Examples

**Good** — uses EARS patterns to match each requirement's nature:
```
media-player
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

**Bad** — enumerates cases:
```
media-player
  when file is "song.mp3"
    then song.mp3 plays
  when file is "track.wav"
    then track.wav plays
```

**Bad** — tautological (then restates the when):
```
media-player
  when a track is loaded
    then a track is loaded
  when playback is paused
    then it pauses
```

**Bad** — flat siblings for causally dependent behaviour:
```
auth
  when token is invalid
    then refresh is attempted
  when refresh fails
    then user is logged out
```

**Good** — causal nesting (refresh failure depends on refresh being attempted):
```
auth
  when token is invalid
    then refresh is attempted
      when refresh fails
        then user is logged out
```

**Bad** — uses implementation language:
```
media-player
  when AudioContext.decodeAudioData resolves
    then the Float32Array buffer is assigned to the source node
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
