---
name: tdd
description: "Enforces test-driven development against test tree requirements in CLAUDE.md. TRIGGER when: changing behaviour, interfaces, or tests."
---

# TDD — Test-Driven Development

## Principles

1. **Outside-in, always** — start with a failing functional test, TDD inward through unit layers
2. **Test trees are the requirements** — the `## Requirements` section in CLAUDE.md contains test trees that specify what the system does. Every test you write traces back to a requirement tree
3. **Two test layers** — functional (real system, no mocks) and unit (isolated, mocked collaborators)
4. **One failing test at a time** — at your current layer, only one test should be red
5. **Mutation testing validates finished work** — run Stryker at the end, never during the cycle
6. **Tree output at every layer** — test output is nested, indented, human-readable

## Before You Start

Read `## Requirements` in the project's CLAUDE.md. The test trees there are your specification. You are implementing against them.

If no requirement tree covers the behaviour you're about to change, **stop and write the requirement tree first** — add it to `## Requirements` in CLAUDE.md before writing any code or tests.

## Process

### 1. CONFIRM REQUIREMENT

Identify which requirement tree in `## Requirements` covers this behaviour. State it explicitly:

> Implementing against requirement tree: `UserRegistration`

If the requirement tree is incomplete (missing scenarios you know you'll need), extend it in CLAUDE.md first.

### 2. RED (functional)

Write a failing functional test that describes the desired behaviour from the consumer's perspective. This test should map directly to a `when/then` path in the requirement tree.

- Exercise the real system through its public surface
- No mocks, no stubs
- The test WILL fail — that's the point

### 3. RED (unit)

Write a failing unit test for the outermost component that needs to change.

### 4. IMPLEMENT

Write only enough code to make the unit test pass. YAGNI.

### 5. GREEN (unit)

Confirm unit tests pass.

### 6. REPEAT (unit)

Continue inward — one failing test at a time. Identify the next layer down, write a failing unit test, implement, pass. Repeat until the outermost component is complete.

### 7. GREEN (functional)

The functional test should now pass. If it doesn't, you've missed something — write another unit test to cover the gap, implement, check again.

### 8. REFACTOR

With all tests green, rework for simplicity and expressiveness. Ensure test trees at both layers read as clear specifications.

### 9. REPEAT

Go to step 1 for the next behaviour (next `when/then` path in the requirement tree).

### 10. MUTATE (end of work)

When all behaviours for current work are complete, run Stryker as final validation. Do NOT run mutation testing during the TDD cycle.

### 11. SYNC REQUIREMENTS

After implementation is complete, check: does the requirement tree in CLAUDE.md still accurately describe the system? Update it if the implementation revealed new understanding.

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
