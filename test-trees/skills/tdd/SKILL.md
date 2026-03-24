---
name: tdd
description: "Enforces test-driven development with human-readable test tree output. TRIGGER when: changing behaviour, interfaces, or tests."
---

# Test-driven development
*All behaviour and/or logic changes must be test driven.* Are you implementing? Ensure you have already written a test! No untested changes!

## Principles

1. **Outside-in, always.** Every behaviour change starts with a failing functional test, then TDDs inward through unit layers. You only build what a real consumer demands.
2. **Tests are specifications.** Test tree output reads as a human-readable description of operating principles — not an enumeration of cases. The tree is the contract.
3. **Two test layers, different jobs.** Functional tests prove the system works end-to-end (no mocks). Unit tests drive internal design with fast, precise feedback (mocked collaborators). Neither replaces the other.
4. **One failing test at a time.** Red → green → refactor, one step at a time, layer by layer.
5. **Mutation testing validates finished work.** Stryker checks whether unit tests actually assert meaningful behaviour. It runs at the end of completed work, not during the TDD cycle.
6. **Tree output at every layer.** Unit tests, functional tests — all produce nested, indented, tree-shaped output by default.

## Test Tree Format
Structure tests so the output reads as a human-readable specification of operating principles:

**GOOD** — describes operating principles (valid, available components are rendered with props):
```text
GeneratedComponent
  when component is valid
    and props are available
      then component is rendered with props
    and props are NOT available
      then component is NOT rendered
  when component is invalid
    then component is NOT rendered
```

**GOOD** — describes operating principles (accepts 0-3 queries):
```text
searchMemoryTool
  parameters schema
    when <= 3 queries provided
      then accepts
    when > 3 queries provided
      then rejects
```

**BAD** — Enumerates specific cases and leaves the reader to infer operating principles (accepts up to 3 queries):
```text
searchMemoryTool
  parameters schema
    when 0 queries provided then accepts
    when 1 query provided then accepts
    when 2 query provided then accepts
    when 3 queries provided then accepts
    when 4 queries provided then rejects
```

## Tests as Contract
*Your test trees are contracts with me* - what you promise our software is doing. That's why you always write tests that produce behaviour-descriptive, human-readable test output when run. You structure such that the output is a *test tree*.

## Tests as Documentation
Tests must describe operating principles, not just specific cases.

This is *BAD*:
```
searchMemoryTool
  parameters schema
    when 1 query provided then accepts
    when 3 queries provided then accepts
    when 0 queries provided then rejects
    when 4 queries provided then rejects
```
It describes specific cases, but not the key operating principles - in this case <= 3 queries are accepted, and > 3 queries are rejected.

So a *GOOD* approach would be:
```
searchMemoryTool
  parameters schema
    when <= 3 queries provided then accepts
    when > 3 queries provided then rejects
```
This is more descriptive, and also less reading and less test code.

It's also important to name the test subject. The top level `describe` should name the export being tested. If there are multiple exports being tested we should describe the implementation filename, with describe blocks for each export nested within.

During TDD, you may create many tests that ultimately exercise the same handling, and elide the same operating principle. In such cases, you can refactor the tests into a smaller, more descriptive set as above.

## Outside-In TDD

You practice London-school, outside-in TDD. Every behaviour change starts from the outside and works inward.

### The Cycle

1. **Start with a failing functional test.** Before touching any unit tests or implementation, write a functional test that describes the desired behaviour from the user's/consumer's perspective. This test exercises the real system through its public surface — no mocks, no stubs. It will fail. That's the point.

2. **Drop to unit tests to TDD the implementation.** With the failing functional test as your north star, identify the outermost component that needs to change. Write a failing unit test for that component. Implement just enough to pass it. Repeat inward — each layer's unit tests drive the design of the next layer down. Mock collaborators at the unit level as needed.

3. **Rise back up.** When enough unit-level implementation exists, the functional test should pass. If it doesn't, you've missed something — write another unit test to cover the gap, implement, and check again.

4. **Refactor across both layers.** With all tests green, refactor for simplicity and expressiveness. Ensure test trees at both layers read as clear specifications.

5. **Mutation test at the end.** When all behaviour for the current piece of work is complete (all functional and unit tests green, code refactored), run Stryker as a final validation. Do NOT run mutation testing during the TDD cycle — it's a quality gate on finished work, not a feedback tool mid-development.

### Why This Order Matters

- The functional test guarantees the behaviour actually works end-to-end.
- Unit tests drive the internal design and provide fast, precise feedback.
- Starting outside-in means you only build what's needed — no speculative internals.
- The functional test catches integration gaps that unit tests with mocks can miss.

### Planning with Test Trees

When planning changes — in plan mode, discussions, or PRs — always express proposed behaviour as test trees at both layers:

```text
FUNCTIONAL: UserRegistration
  when a new user registers with valid details
    then the user account is created
    and a welcome email is sent
  when a new user registers with a duplicate email
    then registration is rejected
    and the existing account is not modified

UNIT: RegistrationService
  when details are valid
    and email is unique
      then creates account via AccountRepository
      then dispatches WelcomeEmail event
    and email is already taken
      then raises DuplicateEmailError
      then does NOT create account

UNIT: AccountRepository
  when creating an account
    then persists to the database
    then returns the created account

UNIT: WelcomeEmailHandler
  when handling a WelcomeEmail event
    then sends email via EmailGateway
```

This makes the outside-in decomposition visible — the functional test states *what* should happen, the unit trees show *how* each layer contributes.

## Process
1. **RED (functional)** Write a failing functional test for the next behaviour — describing the user-visible outcome.
2. **RED (unit)** Write a failing unit test for the outermost component that needs to change.
3. **IMPLEMENT** Write only enough code to make the unit test pass (YAGNI).
4. **GREEN (unit)** Confirm unit tests pass.
5. **REPEAT (unit)** Continue inward — write failing unit tests for the next layer, implement, pass. One failing test at a time.
6. **GREEN (functional)** When enough layers are implemented, confirm the functional test passes.
7. **REFACTOR** Rework implementation across all layers for simplicity (KISS) and expressiveness.
8. **REPEAT** (GOTO 1 for the next behaviour)
9. **MUTATE (end of work)** When all behaviours for the current piece of work are complete, run Stryker to validate unit test quality. Not during the cycle — only at the end.

## Test Layers

### Functional Tests
- Exercise the system through its real public surface (HTTP endpoints, CLI commands, exported API, etc.)
- No mocks — use the real system with real dependencies (or lightweight fakes like in-memory DBs where necessary)
- Slower to run, but prove the system actually works
- Named `*.functional.test.*` (e.g. `registration.functional.test.ts`)
- Located in a `test/functional/` directory at the project root

### Unit Tests
- Test a single module/class/function in isolation
- Mock collaborators to keep tests fast and focused
- Named `*.unit.test.*` (e.g. `registration-service.unit.test.ts`)
- Colocated with the source file they test

### Mutation Testing (Stryker)
- Stryker runs against unit tests to verify test quality
- Run only at the end of a completed piece of work — NOT during the TDD cycle
- Low mutation scores indicate unit tests that pass but don't actually assert meaningful behaviour

## Rules
- Always create both functional and unit tests for behaviour changes.
- Start with a failing functional test, then TDD through unit layers.
- *Only one failing test at a time* at the current layer.
- Functional tests live in `test/functional/` at the project root.
- Unit tests are colocated with the test subject file.
- Interpose `.unit.test` (for unit tests) or `.functional.test` (for functional tests) between the test subject file name and suffix.
  - E.g. `registration.ts` → `test/functional/registration.functional.test.ts` and `registration-service.unit.test.ts` (colocated)
- When in plan mode or otherwise discussing changes with the user, always explain proposed behaviour changes using test trees at both layers.
- If you see an unrelated test is failing, stop and suggest fixing it first.
- If you see a related test is failing, fix it and continue your work.
- If you see a test file is missing, in the wrong place, or has the wrong name, fix it.
- *Fail fast* when deciding what scenarios to test and what to expect — allow errors for unexpected scenarios unless they will be incomprehensible at runtime (assume good observability).
