---
name: tdd
description: "Close gaps between intent and implementation — one failing test at a time, outside-in, until the contract is fulfilled. TRIGGER when: implementing behaviour, writing code, or writing tests."
---

# TDD — Test-Driven Development

## Principles

1. **Outside-in, always** — start with a failing Journey test, then TDD inward: System → Component → driving adapter → use-case → domain → port contract → driven adapter. The Journey test pulls System tests into being, and each System test pulls the hex inner layers; every layer then owns its own complete coverage with its own failing tests at its own seam. "The Journey/System test already covers this unit" is never a reason to skip the unit's own test — nor to implement off the higher failure alone.
2. **Descend to the lowest level, then fold back up** — run the failing higher-layer test, read its failure, and let it guide the next failing test one layer down. Keep descending — through every layer the behaviour touches — to the lowest layer it reaches; never stop descending because the behaviour looks already covered above. Write the full ladder of tests down to the lowest level before any code at that level lands. Then the layers fold back up: make the lowest test pass, and each higher-layer test goes green in turn as the layers beneath it are satisfied, up to the Journey. A higher-layer test still failing means a layer beneath it lacks coverage — write another lower failing test before retrying upward.
3. **Test trees are the contract** — read `## Test Trees` before writing anything. Every test you write reifies exactly one tree. If no tree covers what you're about to build, stop and suggest `change`.
4. **One failing test at a time** — write one failing test, make it pass, then write the next. Never batch.
5. **Mutation testing validates finished work** — run at the end, against Domain and Use-case layers only. Never during the cycle.
6. **Tree output at every layer** — nested, indented, human-readable. Test output reads like the tree.
7. **Don't change existing trees silently** — add new cases as you discover them. Never modify or remove an existing path without asking. The stop hook enforces this.
8. **Keep the tree's labelled parenthesised paths current** — when you create a test or source file at a path the tree does not yet name, update the tree's parenthesised paths to include the new file under its category (`src`, `domain`, `use-case`, `adapter`, `component`, `system`, `journey`) before moving to the next test. If that category was previously `none`, replace it with the new path — closing a declared gap. When you move or rename a file the tree names, update the paths in the same step as the move. TDD is where coverage actually lands on disk, so it is where paths must stay honest.
9. **Correct errors you notice in tree leaf text** — if reading a tree reveals a typo, inaccuracy, or mismatch between a leaf's text and what the test should actually assert, fix the tree leaf first, then write the test mirroring the corrected text. Do not replicate the error in the test. TDD is a second pair of eyes on the tree; leaving known errors unfixed poisons every downstream test.

The layer taxonomy, in-memory adapter pattern, shared port contract suite, and tree-naming heuristic all live in `skills/change/SKILL.md` — that's where decomposition decisions are made. This skill is the tactical cycle that implements those decisions.

**Use-case is to Component as Journey is to System** — two orientations (behaviour-oriented: Use-case, Journey; system-oriented: Component, System) across two realism tiers. The cheap tier doubles what it can (in-memory twins; edge doubles) and is always written and exhaustive; the real tier integrates everything affordable (real infrastructure, maximally integrated) and is selective. The full model lives in `skills/change/SKILL.md`.

## Before You Start

Read `## Test Trees` in the project's CLAUDE.md. The trees there are the contract. You are implementing against them.

If no tree covers the behaviour you're about to implement, **stop and suggest running `change` first** to write the tree before writing any code or tests.

## Process

### 1. CONFIRM TEST TREE

Identify which tree in `## Test Trees` covers this behaviour. State it explicitly:

> Implementing against tree: `save-score`

If the tree seems incomplete, note it but proceed with what's there. Don't modify existing trees — you can add newly discovered cases as you go.

### 2. RED (Journey)

Write **one** failing test at the outermost layer the slice needs. For a new user-visible flow that is a **Journey** test — the expansive arc across capabilities; for a capability under a journey that already exists, it is the **System** test for that capability. It should map directly to a path in the tree.

- Drive through a real driving adapter (HTTP, CLI). **Wire real driven adapters at the highest tolerable realism — real infrastructure, real boundaries.** This is the max-validity functional test that owns the user-visible arc (Journey) or the single capability (System).
- No internal mocks. No stubs. No in-memory driven adapters at this layer.
- A Journey walks **representative** error paths (e.g. an invalid input) and **eventually succeeds** — it does not enumerate every error; those belong to the layers below.
- **Keep the Journey runnable in under 5 minutes.** It is curated, never exhaustive — when it runs longer, trim it to the highest-impact (most damaging if broken) and most-recent (most likely to break) steps; trimmed behaviour stays covered at lower layers. Re-evaluate and trim the journey whenever you touch it, and do not auto-add a journey step for every capability.
- When breadth at max realism is unaffordable, lean on the journey and push combinatorial detail down to inner layers — never wire many in-memory System tests. If you're tempted to wire in-memory at the System layer to "get faster tests", you want a Use-case test instead; write one when implementation pressure asks for it.
- The test WILL fail — that's the point.
- **Write exactly one test. Run it. See it fail. Then proceed.**
- **If the test passes unexpectedly** — break the implementation intentionally (comment out the code path), observe the test failing, fix it, observe it passing, move on. A test that can't fail protects nothing.

### 3. IDENTIFY LAYER, THEN RED (inner)

Run the failing higher-layer test and read its failure — it names what is missing and points at the next layer down. Decompose the failing path into the layers it touches, pick the **outermost untested layer**, and write one failing test there. **Keep descending — one layer at a time, through every layer the behaviour touches — to the lowest layer it reaches, and do not write any implementation until a failing test exists at that ground layer, sitting *under* the journey/functional failure.** Never stop descending because the behaviour looks already covered above: Journey and functional coverage is not coverage of the layers beneath, and a Journey or System test, red or green, never licenses implementing the unit beneath it. "Already covered above" is the signal to write the unit's own failing test, not to skip it. Write the full ladder of tests down to the lowest level.

Questions in order:

- **Does the path cross a whole-app capability the journey traverses but no System test yet pins?** Write a System test for that one capability — the whole app wired with real driven adapters against real infrastructure. Selective: write one when the capability earns real-infra confidence, not for every capability.
- **Does the path's capability need its assembled behaviour exercised broadly and cheaply?** Write a Component test — the whole app for that one capability with real adapters, externals doubled at the edge (in-memory database, stubbed outbound HTTP), in-process. This carries the exhaustive single-capability breadth.
- **Does the path cross a driving-adapter boundary** (HTTP/CLI/queue/cron)? If the translation is non-trivial — routing, deserialization, auth extraction, error-code shaping — write a driving-adapter test with the use-case mocked.
- **Does the path orchestrate** (call a domain factory, invoke one or more ports, branch on results)? Write a use-case test. In-memory driven adapters satisfy the ports; domain factories are real.
- **Does the path compute a pure rule** over data with no collaborators? Write a domain test.
- **Does the path require a new outbound port or a new method on an existing one?** Write the shared port contract suite (the `ScoreRepository` tree) first. Both the in-memory adapter and, later, the real adapter must satisfy it.
- **Has all application behaviour been covered but the real infrastructure still needs wiring?** Write a driven-adapter test against real infra. It runs the shared contract suite plus any adapter-specific behaviour (timeouts, retries, schema).

Do not write tests for multiple layers in one step.

- **If the test passes unexpectedly** — break the implementation intentionally, observe failure, fix, observe passing, move on.

### 4. IMPLEMENT

Write only enough code to make the failing test pass. YAGNI. **Never write implementation off a journey/System failure alone — only once the failing test at the behaviour's own ground layer exists (step 3).**

### 5. GREEN (inner)

Confirm the inner test passes.

### 6. REPEAT (inner)

Continue inward — **one failing test at a time**. Write one, run it, see it fail, implement, see it pass. Then the next. Never batch.

### 7. FOLD BACK UP

Once the lowest-layer test passes, the layers fold back up: the Use-case test, then the System test, then the Journey test pass in turn as the layers beneath them are satisfied. If a higher-layer test still fails, a layer beneath it lacks coverage — write another lower failing test to close the gap, implement, then re-run upward.

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
- Tree shape depends on the layer — see "Tree shape per layer" in `skills/change/SKILL.md`. At Domain, Use-case, and Port-contract, top-level describes are the unit's functions/methods and every path is an observable branch. At Journey, System, and Adapter, the tree describes behaviour at the seam.
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

### Journey (`*.journey.test.*` in `test/journey/`)
- Import: the composition root **wired with real driving and driven adapters, real infrastructure, real boundaries** — the highest realism the project can run.
- Drive the full user arc across capabilities through the real driving adapter; assert on observable effects through that adapter at each step.
- Walk one **representative** error path (e.g. an invalid input), let the arc recover, and **eventually succeed** — do not enumerate every error here; those live at the layers below.
- Keep it runnable in under 5 minutes; curated, not exhaustive. When it exceeds that budget, trim to the highest-impact and most-recent steps — the rest stays covered at lower layers.
- The outside-in entry point. Everything below appears only because this test cannot be satisfied without it.

### System (`*.system.test.*` in `test/system/`)
- Import: the composition root **wired with real driven adapters at the highest tolerable realism** (Testcontainers, local service, sandbox account), plus the real driving adapter — scoped to a single capability.
- Drive the real driving adapter; assert on observable effects through the same adapter.
- Max-validity functional testing of one capability, interior to the journey. When breadth at max realism is unaffordable, lean on the journey rather than wiring many in-memory System tests.

### Outside-in order

1. **Journey** — one failing test for the user arc, at max realism. The outside-in entry point and the only test required up front. Everything below appears only because this test cannot be satisfied without it.
2. **System** — one failing test per capability the journey traverses, the whole app wired with real driven adapters. Interior to the journey.
3. **Driving adapter** — one failing test for protocol mapping. Mock the use-case. (Only when the translation is non-trivial.)
4. **Use-case** — one failing test for orchestration. In-memory driven adapters. (Only when orchestration exists and the System test alone can't drive it cheaply enough.)
5. **Domain** — one failing test for the pure rule. No collaborators. (Only when there's a pure rule worth isolating.)
6. **Port contract** — write the shared suite (`*.contract.ts`). Both in-memory and real adapters must pass it. (Only when a port exists.)
7. **Driven adapter** — implement the real adapter. Shared suite runs green; add adapter-specific tests. (Reality of the driven adapter is also exercised through the System test — driven-adapter tests cover adapter-local behaviour beyond the port contract.)

Every failing test sits at a named layer. If you can't name the layer, you're not decomposed enough. Equally: if you can't name the implementation pressure from the failing journey/functional test that forces this inner test to exist, don't write it yet.

**When the Journey or a System test pulls a new unit into being, that unit gets its own tree and its own failing test at its native ground layer — before any implementation lands.** Journey and functional coverage is not coverage of the unit beneath. Do not lean on a higher-layer test as the unit's coverage; it isn't. If you find yourself thinking "the journey/System test already exercises this so I'll skip the unit test," that is the signal to write the unit's tree and failing test, not to skip it — and never to implement off the higher failure alone. Overlap between layers is the intended shape — unit tests prove the unit is complete on its own terms; higher tests prove the wiring and the user-visible arc.

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
