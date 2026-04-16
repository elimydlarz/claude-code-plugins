---
name: tdd
description: "Close gaps between intent and implementation — one failing test at a time, outside-in, until the contract is fulfilled. TRIGGER when: implementing behaviour, writing code, or writing tests."
---

# TDD — Test-Driven Development

## Principles

1. **Outside-in, always** — start with a failing System test for the slice, then TDD inward through the hex seams: driving adapter, use-case, domain; outbound port → driven adapter integration last. See the Test Layers section for the mapping.
2. **Test trees are the contract** — the `## Test Trees` section in CLAUDE.md contains every tree. Each tree describes one behavioural unit: a domain object, a use-case, an adapter, a port contract, or a slice. Every test you write reifies one tree.
3. **One tree ↔ one test file** — each tree maps to exactly one test file. The file's `describe`/`it` hierarchy mirrors the tree verbatim. Finding a test from a tree (or vice versa) should take zero search.
4. **Four test layers mapped to hex seams** — Domain, Use-case, Adapter (driving and driven), System. Layers are named for the architectural seam under test, not for infrastructure presence. See the Test Layers section for the full mapping.
5. **In-memory adapters are first-class** — each driven port has two adapters: the real one (Postgres, Stripe, filesystem) and an in-memory one. Both satisfy the same port contract. Use-case and System tests run against the in-memory adapter for speed.
6. **The port contract suite is shared** — one contract suite per port, imported by both the real-adapter Adapter test AND the in-memory-adapter Adapter test. Both must pass the same suite. That's what makes substitution sound.
7. **One failing test at a time** — write exactly one failing test, make it pass, then write the next. If you catch yourself writing more than one `it`/`test` block before running tests, stop and delete all but the first.
8. **Mutation testing validates finished work** — run mutation testing at the end, never during the cycle.
9. **Tree output at every layer** — nested, indented, human-readable. The test output reads like the tree.
10. **Don't change existing trees silently** — TDD may discover new cases; add them. But never modify or remove an existing `when/then` path without asking.

## Before You Start

Read `## Requirements` in the project's CLAUDE.md. The test trees there are your specification. You are implementing against them.

If no test tree covers the behaviour you're about to implement, **stop and suggest running `change` first** to write the test tree before writing any code or tests.

## Process

### 1. CONFIRM TEST TREE

Identify which tree in `## Test Trees` covers this behaviour. State it explicitly:

> Implementing against tree: `save-score`

If the tree seems incomplete, note it but proceed with what's there. Don't modify existing trees — you can add newly discovered cases as you go.

### 2. RED (System)

Write **one** failing System test for the slice. It should map directly to a single `when/then` path in the tree.

- Drive through a real driving adapter (HTTP, CLI). In-memory driven adapters — not mocks.
- No internal mocks. No stubs.
- The test WILL fail — that's the point.
- **Write exactly one test. Run it. See it fail. Then proceed.**
- **If the test passes unexpectedly** — break the implementation intentionally (comment out the code path), observe the test failing, fix it, observe it passing, move on. A test that can't fail protects nothing.

### 3. IDENTIFY LAYER, THEN RED (inner)

Before writing the next test, decompose the failing path into the hex seams it touches. Pick the **outermost untested layer** and write one failing test there.

Questions in order:

- **Does the path cross a driving-adapter boundary** (HTTP/CLI/queue/cron)? If the translation is non-trivial — routing, deserialization, auth extraction, error-code shaping — write a driving-adapter test with the use-case mocked.
- **Does the path orchestrate** (call a domain factory, invoke one or more ports, branch on results)? Write a use-case test. In-memory driven adapters satisfy the ports; domain factories are real.
- **Does the path compute a pure rule** over data with no collaborators? Write a domain test.
- **Does the path require a new outbound port or a new method on an existing one?** Write the shared port contract suite (the `ScoreRepository` tree) first. Both the in-memory adapter and, later, the real adapter must satisfy it.
- **Has all application behaviour been covered but the real infrastructure still needs wiring?** Write a driven-adapter test against real infra. It runs the shared contract suite plus any adapter-specific behaviour (timeouts, retries, schema).

Do not write tests for multiple layers in one step.

- **If the test passes unexpectedly** — break the implementation intentionally, observe failure, fix, observe passing, move on.

### 4. IMPLEMENT

Write only enough code to make the failing test pass. YAGNI.

### 5. GREEN (inner)

Confirm the inner test passes.

### 6. REPEAT (inner)

Continue inward — **one failing test at a time**. Write one, run it, see it fail, implement, see it pass. Then the next. Never batch.

### 7. GREEN (System)

The System test should now pass. If it doesn't, a layer is missing coverage — write another inner test to close the gap, implement, re-run System.

### 8. REFACTOR

With all tests green, refactor the code you just changed — no broader. Resist the pull to keep tidying; it delays facing the next test. Duplication is a hint, not a command — don't extract abstractions until patterns have proven themselves.

### 9. REPEAT

Go to step 1 for the next behaviour (next `when/then` path in the test tree).

### 10. MUTATE (end of work)

When all behaviours for current work are complete, run mutation testing as final validation. Do NOT run mutation testing during the TDD cycle.

### 11. SUGGEST SYNC

After implementation is complete, suggest the user runs `sync` to verify test trees and implementation are aligned.

## Test Tree Format

Test trees describe **operating principles**, not case enumerations. Use EARS patterns (see EARS Patterns below) to choose the right keyword for each requirement.

GOOD — uses EARS patterns to match each requirement's nature:
```
UserRegistration
  then passwords are stored hashed, never in plain text
  when a new user registers with valid details
    then the user account is created
    and a welcome email is sent
  if the email is already registered
    then registration is rejected
    and the existing account is not modified
```

BAD — enumerates cases:
```
UserRegistration
  when name is "Alice"
    then account for Alice is created
  when name is "Bob"
    then account for Bob is created
```

### Rules

- Top level names the subject (capability for functional, module/function for unit)
- Use EARS keywords (`when`, `while`, `if`, `where`, or bare `then`) to match the requirement's nature
- `then` describes outcomes (what the consumer observes)
- Use `if/then` for error cases and unwanted behaviour
- Describe principles, not specific values

## Test Layers

Contree defines **four test layers**, each mapped to a seam in the hexagonal architecture:

```
  [ Driving Adapter ]  ←→  [ Port ]  ←→  [ Use-case ]  ←→  [ Port ]  ←→  [ Driven Adapter ]
     (HTTP / CLI)             (iface)      (orchestration)   (iface)       (Postgres / Stripe / FS)
                                                 ↕
                                           [ Domain ]
                                    (entities, value objects,
                                     domain services, rules)
```

| Layer       | Seam under test                  | Collaborators                                           | Speed     | File convention            |
| ----------- | -------------------------------- | ------------------------------------------------------- | --------- | -------------------------- |
| Domain      | the pure core                    | none — no fakes, no mocks, no async                     | instant   | `*.domain.test.*`          |
| Use-case    | orchestration + port boundaries  | in-memory adapters (real implementations of the ports) | fast      | `*.use-case.test.*`        |
| Adapter     | one adapter against its contract | driving: mocked use-case. driven: real infrastructure.  | mixed     | `*.adapter.test.*`         |
| System      | the whole wired app              | in-memory driven adapters by default; real on demand    | slow      | `*.system.test.*` in `test/system/` |

**Why layer by seam, not by infrastructure:** the classic unit/integration/functional triad describes *how much real stuff is wired in*. Hex gives you named seams with typed contracts — so layer by seam, and the mocking posture falls out of the architecture instead of being chosen per test.

### Layer 1 — Domain

Pure domain objects and services: entities, value objects, aggregates, domain services, invariants.

- **No collaborators.** No ports, no mocks, no fakes. If you need a fake here, the domain has leaked infrastructure — fix the design, don't test through it.
- **No async, no setup, no teardown.** Just functions over data.
- **One tree per domain object or service** (`Money`, `SessionToken`, `LeaderboardRanking`). Tree names it; test file reifies it.

Write a domain tree only when the rule is substantive — many cases, edge behaviour, algorithmic depth, or reuse across multiple use-cases. Trivial domain types don't earn their own tree; they're covered implicitly by the use-case that owns them.

### Layer 2 — Use-case

Application services / interactors — the orchestration code that drives domain objects and calls outbound ports.

- **Ports are faked with in-memory adapters**, not strict mocks. The in-memory adapter is a real implementation of the port contract (stores data in a map, enforces the same invariants). See *In-memory adapters* below.
- **Verifies what the application does**: the right port is called with the right data, the right domain factory is invoked, the right error is raised. Catches coordination bugs.
- **Does not verify HTTP/CLI wiring** — that's the driving-adapter test's job. Does not verify Postgres serialization — that's the driven-adapter test's job.
- **One tree per use-case** (`save-score-use-case`, `cancel-order-use-case`).

### Layer 3 — Adapter

One adapter in isolation, verified against its port contract. Split by direction:

- **Driving adapter tests** — HTTP controller, CLI handler, queue consumer. Application mocked. Verify protocol-to-input mapping: routing, deserialization, error-code shaping, auth extraction. File lives next to the adapter.
- **Driven adapter tests** — Postgres repository, Stripe client, filesystem writer. Real infrastructure (Testcontainers, local service, recorded cassettes). Verify the adapter satisfies the port contract against the real thing. File lives next to the adapter.

Naming: `*.adapter.test.*` in both directions. Tree name is the adapter itself (`score-http-handler`, `ScoreRepository-Postgres`, `AuditLog-FileSystem`).

**Driven adapter tests use the shared port contract suite** — see below.

### Layer 4 — System

The whole app assembled, driven through a real driving adapter (HTTP, CLI), with driven adapters substituted for in-memory by default and real on demand.

- **Default: in-memory driven adapters.** Acceptance-level confidence at Use-case speed. Runs in CI on every push.
- **On-demand: real driven adapters.** Same System tests, but wired against Testcontainers or a staging environment. Run before release, not on every push.
- **One tree per slice** (`save-score`, `cancel-order`, `user-registration`). One System test file per tree; the file's `describe`/`it` hierarchy mirrors the tree. Lives in `test/system/`.
- **Plus cross-cutting trees** (`auth-enforcement`, `rate-limiting`, `error-envelope`) for app-level invariants that aren't per-slice.

**Outside-in TDD starts here.** Write a failing System test first. Then TDD inward through Driving adapter → Use-case → Domain / Port → Driven adapter (integration against real infra).

---

## The in-memory adapter pattern

This is the linchpin of the whole scheme. Without it, Use-case and System tests either get slow (real infra) or dishonest (mocks that don't match reality).

For each driven port, ship two adapters that both satisfy the port contract:

```
OrderRepository (port interface)
├── PostgresOrderRepository    ← real, used in production and in driven-adapter tests
└── InMemoryOrderRepository    ← real, used in Use-case and System tests
```

The in-memory adapter is not a mock. It's a real implementation: stores data in a map, enforces the same invariants (unique IDs, referential rules, ordering guarantees) that the real adapter does. Swap it in at composition time by pointing the composition root at a different wiring.

What this buys:

- Use-case tests run in milliseconds against *real application behaviour*.
- System tests run fast by default, covering the full vertical slice.
- The real adapter's job shrinks to "adapt Postgres to the port" — everything application-level is already covered by tests running against the in-memory adapter.

---

## The shared port contract suite

In-memory substitution is only sound if both adapters really do satisfy the same contract. Contree enforces this with a **shared port contract suite**: one test suite, imported by both adapter test files.

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
      it('rejects the second call without side effects', async () => { ... })
    })
  })
}
```

```ts
// src/features/score/adapters/outbound/in-memory-score-repository.adapter.test.ts
import { scoreRepositoryContract } from '../../application/ports/score-repository.contract'
scoreRepositoryContract(() => new InMemoryScoreRepository())
```

```ts
// src/features/score/adapters/outbound/postgres-score-repository.adapter.test.ts
import { scoreRepositoryContract } from '../../application/ports/score-repository.contract'
scoreRepositoryContract(() => new PostgresScoreRepository(testDb))
// Plus Postgres-specific tests: timeouts, schema, constraint violations.
```

The contract suite IS the port contract tree (`ScoreRepository`). Both adapter tests pass the shared suite. The Postgres adapter *also* has its own tests for behaviour that only exists at the Postgres seam (timeouts, retries, constraint violations) — those live in the same `*.adapter.test.*` file but outside the shared suite.

Tree in `## Test Trees`:

```
ScoreRepository
  when save is called with a score
    then the score is retrievable by its id
  if save is called twice with the same score id
    then the second call is rejected without side effects
```

---

## One tree per behavioural unit

Every behavioural unit gets its own tree in `## Test Trees`, flat and unsectioned. Each tree maps 1:1 to a test file:

| Tree                          | Test file                                                 | Layer     |
| ----------------------------- | --------------------------------------------------------- | --------- |
| `save-score`                  | `test/system/save-score.system.test.ts`                   | System    |
| `score-http-handler`          | `score-http-handler.adapter.test.ts` (colocated)          | Adapter (driving) |
| `save-score-use-case`         | `save-score.use-case.test.ts` (colocated)                 | Use-case  |
| `ScoreRepository`             | `score-repository.contract.ts` (colocated with port)      | — (shared suite) |
| `ScoreRepository-Postgres`    | `postgres-score-repository.adapter.test.ts` (colocated)   | Adapter (driven)  |
| `SessionToken`                | `session-token.domain.test.ts` (colocated)                | Domain    |

**Heuristic for whether a unit earns a tree:** does the unit have behavioural choices someone could change silently? If yes, tree. If no (trivial pass-through — a one-line adapter that just calls the use-case, a use-case that just delegates to a single port), it's covered by the parent System tree.

### Tree naming heuristic

**Name each tree for the subject with observable behaviour at its layer.**

| Layer    | Subject is...                          | Examples                                         |
| -------- | -------------------------------------- | ------------------------------------------------ |
| Domain   | the domain object or service           | `SessionToken`, `Money`, `LeaderboardRanking`    |
| Use-case | the use-case                           | `save-score-use-case`, `cancel-order-use-case`   |
| Port     | the port interface (shared contract)   | `ScoreRepository`, `AuditLog`                    |
| Adapter  | the adapter being exercised            | `score-http-handler`, `ScoreRepository-Postgres` |
| System   | the capability/slice, not the whole app | `save-score`, `user-registration`               |

Cross-cutting System trees name the policy: `auth-enforcement`, `rate-limiting`, `error-envelope`.

---

## Outside-in order

1. **System** — one failing test for the slice, in `test/system/`. Mirrors the tree verbatim.
2. **Driving adapter** — one failing test for protocol mapping. Mock the use-case.
3. **Use-case** — one failing test for orchestration. In-memory driven adapters. Domain factories real.
4. **Domain** — one failing test for the pure rule. No collaborators.
5. **Port contract** — write the shared suite. Both in-memory and real adapters must pass it.
6. **Driven adapter** — implement the real adapter. Shared suite runs green against it; add Postgres-specific tests for timeout/retry/constraint behaviour.

Every failing test sits at a named layer. If you can't name the layer, you're not decomposed enough.

---

## Beyond the minimum

Additive test kinds are welcome when they earn their keep — multi-slice System journeys, consumer-driven contract tests with external peers, load tests, characterization tests. They supplement the four layers; they don't replace them.

---

## Mutation Testing
- Stryker validates unit-test quality at the Domain and Use-case layers.
- Run at end of completed work; never during the cycle.
- Tests that survive mutants are too permissive.

## Handling Failing Tests

- **Unrelated failure**: fix it first, then continue
- **Related failure**: fix and continue the cycle
- **Missing/wrong test**: fix the test, then continue
- Fail fast when deciding scenarios; allow errors unless incomprehensible

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
