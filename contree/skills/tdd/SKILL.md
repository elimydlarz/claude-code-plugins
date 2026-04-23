---
name: tdd
description: "Close gaps between intent and implementation — one failing test at a time, outside-in, until the contract is fulfilled. TRIGGER when: implementing behaviour, writing code, or writing tests."
---

# TDD — Test-Driven Development

## Principles

1. **Outside-in, always** — start with a failing System test, then TDD inward: driving adapter → use-case → domain → port contract → driven adapter.
2. **Test trees are the contract** — read `## Test Trees` before writing anything. Every test you write reifies exactly one tree. If no tree covers what you're about to build, stop and suggest `change`.
3. **One failing test at a time** — write one failing test, make it pass, then write the next. Never batch.
4. **Mutation testing validates finished work** — run at the end, against Domain and Use-case layers only. Never during the cycle.
5. **Tree output at every layer** — nested, indented, human-readable. Test output reads like the tree.
6. **Don't change existing trees silently** — add new cases as you discover them. Never modify or remove an existing path without asking. The stop hook enforces this.
7. **Keep the tree's parenthesised paths current** — when you create a test or source file at a path the tree does not yet name, update the tree's parenthesised paths to include the new file before moving to the next test. When you move or rename a file the tree names, update the paths in the same step as the move. TDD is where coverage actually lands on disk, so it is where paths must stay honest.
8. **Correct errors you notice in tree leaf text** — if reading a tree reveals a typo, inaccuracy, or mismatch between a leaf's text and what the test should actually assert, fix the tree leaf first, then write the test mirroring the corrected text. Do not replicate the error in the test. TDD is a second pair of eyes on the tree; leaving known errors unfixed poisons every downstream test.

The layer taxonomy, in-memory adapter pattern, shared port contract suite, and tree-naming heuristic all live in `skills/change/SKILL.md` — that's where decomposition decisions are made. This skill is the tactical cycle that implements those decisions.

## Before You Start

Read `## Test Trees` in the project's CLAUDE.md. The trees there are the contract. You are implementing against them.

If no tree covers the behaviour you're about to implement, **stop and suggest running `change` first** to write the tree before writing any code or tests.

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

- Top level names the subject — see the naming heuristic in `skills/change/SKILL.md`.
- Tree shape depends on the layer — see "Tree shape per layer" in `skills/change/SKILL.md`. At Domain, Use-case, and Port-contract, top-level describes are the unit's functions/methods and every path is an observable branch. At Adapter and System, the tree describes behaviour at the seam.
- Use EARS keywords (`when`, `while`, `if`, `where`, or bare `then`) to match the requirement's nature.
- `then` describes outcomes.
- Use `if/then` for error cases and unwanted behaviour.
- Tree names must be unique within `## Test Trees`. One tree, one test file.
- **Tree ≡ describe/it hierarchy verbatim** — every path in the tree appears as a describe/it in the test file; every describe/it in the test file appears as a path in the tree.

## Writing Tests at Each Layer

Tactical cheatsheet for the RED/GREEN cycle. See `skills/change/SKILL.md` for the full layer taxonomy, seam diagram, in-memory adapter pattern, shared port contract suite, and naming heuristic — that's where the strategic decisions live.

### Domain (`*.domain.test.*`, colocated)
- Import: the domain object/service under test.
- Collaborators: none.
- Call functions directly, assert on returned data.
- **Shape**: top-level describe is the unit; second-level describes are its exported functions/methods; inner describes are branches.

### Use-case (`*.use-case.test.*`, colocated)
- Import: the use-case plus the in-memory adapter for each outbound port it depends on.
- Wire: instantiate the use-case with the in-memory adapters.
- Assert on returned data and on the in-memory adapter's state (what was saved, what was queried).
- **Shape**: top-level describe is the use-case; second-level describes are its entry points (usually one — `execute` or the function); inner describes are branches.

### Adapter — driving (`*.adapter.test.*`, colocated)
- Import: the driving adapter plus a mock of the use-case.
- Assert: protocol-to-input translation — routing, deserialization, error-code shaping, auth extraction.

### Adapter — driven (`*.adapter.test.*`, colocated)
- Import: the real adapter, the shared contract suite (`*.contract.ts`), plus any real-infra test helpers (Testcontainers, local service, etc.).
- Run the shared contract suite against the real adapter. Add adapter-specific tests for behaviour beyond the port contract (timeout, retry, schema, constraint handling).

### System (`*.system.test.*` in `test/system/`)
- Import: the composition root (wired with in-memory driven adapters by default) plus the real driving adapter.
- Drive the real driving adapter; assert on observable effects through the same adapter.
- A separate command reruns the System suite with real driven adapters wired for pre-release verification.

### Outside-in order

1. **System** — one failing test for the slice.
2. **Driving adapter** — one failing test for protocol mapping. Mock the use-case.
3. **Use-case** — one failing test for orchestration. In-memory driven adapters.
4. **Domain** — one failing test for the pure rule. No collaborators.
5. **Port contract** — write the shared suite (`*.contract.ts`). Both in-memory and real adapters must pass it.
6. **Driven adapter** — implement the real adapter. Shared suite runs green; add adapter-specific tests.

Every failing test sits at a named layer. If you can't name the layer, you're not decomposed enough.

---

## Mutation Testing
- Stryker validates test quality at the Domain and Use-case layers.
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
