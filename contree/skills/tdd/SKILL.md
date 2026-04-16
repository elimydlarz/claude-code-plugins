---
name: tdd
description: "Close gaps between intent and implementation — one failing test at a time, outside-in, until the contract is fulfilled. TRIGGER when: implementing behaviour, writing code, or writing tests."
---

# TDD — Test-Driven Development

## Principles

1. **Outside-in, always** — start with a failing functional test, TDD inward through the hex positions in this order: inbound adapter, use-case, domain and outbound ports, outbound adapter
2. **Test trees are the requirements** — the `## Requirements` section in CLAUDE.md contains test trees that specify what the system does. Every test you write traces back to a test tree
3. **Three test layers** — unit (isolated, fakes for collaborators), integration (real infrastructure for outbound adapters), functional (whole system, no mocks). Each hex position has a default layer and mocking posture — see the Positions and Layers section below
4. **One failing test at a time** — write exactly one failing test, make it pass, then write the next. Never write multiple failing tests in a single step. If you catch yourself writing more than one `it`/`test` block before running tests, stop and delete all but the first
5. **Mutation testing validates finished work** — run mutation testing at the end, never during the cycle
6. **Tree output at every layer** — test output is nested, indented, human-readable
7. **Don't change existing trees** — TDD may discover new test cases, but existing trees are the spec. Add new cases as you discover them, but don't modify or remove existing `when/then` paths

## Before You Start

Read `## Requirements` in the project's CLAUDE.md. The test trees there are your specification. You are implementing against them.

If no test tree covers the behaviour you're about to implement, **stop and suggest running `change` first** to write the test tree before writing any code or tests.

## Process

### 1. CONFIRM TEST TREE

Identify which test tree in `## Requirements` covers this behaviour. State it explicitly:

> Implementing against test tree: `UserRegistration`

If the test tree seems incomplete, note it but proceed with what's there. Don't modify existing trees — you can add newly discovered cases as you go.

### 2. RED (functional)

Write **one** failing functional test that describes the desired behaviour from the consumer's perspective. This test should map directly to a single `when/then` path in the test tree.

- Exercise the real system through its public surface
- No mocks, no stubs
- The test WILL fail — that's the point
- **Write exactly one test. Run it. See it fail. Then proceed.**
- **If the test passes unexpectedly** — the behaviour already exists or the test is wrong. You must verify the test actually tests what it claims: break the implementation intentionally (e.g. comment out the relevant code path), observe the test failing, then fix the implementation, observe the test passing, and move on. If breaking the implementation doesn't make the test fail, the test is not verifying the behaviour — fix the test until it does.

### 3. IDENTIFY POSITION, THEN RED (unit)

Before writing the next test, decompose the current `when/then` path into the hex positions it actually touches:

- **Transport** — does the path cross an HTTP/CLI/queue/cron boundary? That's an inbound adapter whose protocol mapping needs its own test.
- **Orchestration** — does the path coordinate multiple concerns (validate input, call a collaborator, update state, emit an event)? That's the use-case.
- **Side effects** — does the path persist, call an external service, read time, emit audits, produce randomness, or do I/O? Each is an outbound port. Name ports for capability (`AuditLog`, `ScoreRepository`), never for technology (`PostgresClient`, `StripeSDK`).
- **Pure rules** — does the path compute over data with no collaborators? That's the domain.

Pick the outermost untested position and write **one** failing test there:

- Inbound adapter present but untested → test protocol mapping.
- Orchestration + side effects → **use-case test with ports faked**. Assert both the returned data and the port interactions. This is NOT a domain test — collapsing a side effect into a domain object is a hex violation.
- Orchestration without side effects → use-case test, no fakes needed beyond the use-case's own inputs.
- No orchestration, no side effects → **domain test**: pure functions over data, no mocks.
- Trivial path (one function, no orchestration, no side effects) → no unit test. The functional test is enough.

Do not write tests for multiple behaviours or layers — just the single next thing that needs to fail.

- **If the test passes unexpectedly** — break the implementation intentionally, observe the test failing, then fix the implementation, observe the test passing, and move on. A test that can't fail doesn't protect anything.

### 4. IMPLEMENT

Write only enough code to make the unit test pass. YAGNI.

### 5. GREEN (unit)

Confirm unit tests pass.

### 6. REPEAT (unit)

Continue inward — **one failing test at a time**. Write one test, run it, see it fail, implement, see it pass. Then and only then write the next test. Never batch multiple tests into a single step, even if you know what they all need to be.

### 7. GREEN (functional)

The functional test should now pass. If it doesn't, you've missed something — write another unit test to cover the gap, implement, check again.

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

### Outside-In Order

Contree prescribes hexagonal architecture. Drive tests inward in this order:

1. **Functional** — whole vertical slice. One test per `when/then` path in the tree.
2. **Inbound adapter** (unit) — protocol → use-case input mapping. HTTP/CLI/queue payloads translated to plain input; results translated back.
3. **Use-case** (unit) — orchestration. Outbound ports faked; assert returned data and port interactions.
4. **Domain** (unit) — pure business rules. No mocks, no async, no setup.
5. **Outbound adapter** (integration) — real infrastructure. DB queries, HTTP calls, queue publishing.

Every failing test you write should sit at a specific layer. If you can't name the layer, you're not decomposed enough.

### Functional Tests
- Exercise real public surface, no mocks
- `test/functional/` at project root
- `*.functional.test.*` naming
- Prove the system works end-to-end

### Unit Tests
- Single module/class/function in isolation
- Mock collaborators (for use-cases, the collaborators are outbound ports)
- Colocated with source
- `*.unit.test.*` naming
- Drive internal design with fast feedback
- Domain tests use no mocks — pure functions over data

### Outbound Adapter Integration Tests
- Hit real infrastructure (DB, API, queue)
- Verify serialization, schema/query behaviour, timeouts
- Slower than unit tests — keep the set focused

### Mutation Testing
- Stryker validates unit test quality
- Run only at end of completed work
- Tests that pass with mutations are too permissive

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
