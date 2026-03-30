---
name: tdd
description: "Close gaps between intent and implementation — one failing test at a time, outside-in, until the contract is fulfilled. TRIGGER when: implementing behaviour, writing code, or writing tests."
---

# TDD — Test-Driven Development

## Principles

1. **Outside-in, always** — start with a failing functional test, TDD inward through unit layers
2. **Test trees are the requirements** — the `## Requirements` section in CLAUDE.md contains test trees that specify what the system does. Every test you write traces back to a test tree
3. **Two test layers** — functional (real system, no mocks) and unit (isolated, mocked collaborators)
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

### 3. RED (unit)

Write **one** failing unit test for the outermost component that needs to change. Do not write tests for multiple behaviours or layers — just the single next thing that needs to fail.

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

With all tests green, rework for simplicity and expressiveness. Ensure test trees at both layers read as clear specifications.

### 9. REPEAT

Go to step 1 for the next behaviour (next `when/then` path in the test tree).

### 10. MUTATE (end of work)

When all behaviours for current work are complete, run mutation testing as final validation. Do NOT run mutation testing during the TDD cycle.

### 11. SUGGEST SYNC

After implementation is complete, suggest the user runs `sync` to verify test trees and implementation are aligned.

## Test Tree Format

Test trees describe **operating principles**, not case enumerations.

GOOD — describes principles:
```
UserRegistration
  when a new user registers with valid details
    then the user account is created
    and a welcome email is sent
  when the email is already registered
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
- `when` describes conditions (nest with `and` for compound conditions)
- `then` describes outcomes (what the consumer observes)
- Include negative paths (what happens when invalid, absence of behaviour)
- Describe principles, not specific values

## Test Layers

### Functional Tests
- Exercise real public surface, no mocks
- `test/functional/` at project root
- `*.functional.test.*` naming
- Prove the system works end-to-end

### Unit Tests
- Single module/class/function in isolation
- Mock collaborators
- Colocated with source
- `*.unit.test.*` naming
- Drive internal design with fast feedback

### Mutation Testing
- Stryker validates unit test quality
- Run only at end of completed work
- Tests that pass with mutations are too permissive

## Handling Failing Tests

- **Unrelated failure**: fix it first, then continue
- **Related failure**: fix and continue the cycle
- **Missing/wrong test**: fix the test, then continue
- Fail fast when deciding scenarios; allow errors unless incomprehensible
