---
name: workflow
description: "Run the full Contree arc from idea to verified software: change sets expected behaviour, sync finds drift and gaps, tdd closes them, and second-opinion reviews the result. TRIGGER when: the user wants the full workflow, asks to take an idea through implementation, asks to make the project complete, or wants change/sync/tdd handled end to end."
---

# Workflow

Carries an idea through the full arc: from intent to contract to verified implementation. Sets expected behaviour, identifies where reality diverges, and closes every gap — without pausing for review.

## When to Use

- When the user shares an idea and wants it built
- When the user wants the full cycle without manual phase transitions
- As an alternative to running `change`, `sync`, and `tdd` individually

## Process

### 1. CHANGE — set expected behaviour

Run the `change` skill process: understand the behaviour, identify the consumer, write or modify test trees in `## Test Trees`, decompose across layers and positions. **Outside-in: for a new user-visible flow the Journey tree is the only tree to write up front** (a capability under an existing journey starts as that capability's System tree). System and inner trees (Use-case, Domain, Port, Adapter) get added in step 3 (TDD) as the failing journey/functional test pulls them into being — not pre-specified here.

Do not pause for alignment — proceed directly.

### 2. SYNC — identify gaps and cruft

Run the `sync` skill process: load the test trees, inventory the implementation, compare both directions, resolve drift, identify gaps.

Do not pause to present gaps — proceed directly to implementation.

### 3. TDD — close gaps

For each gap identified by sync, run the `tdd` skill process: confirm test tree, RED journey, RED system/functional, RED unit at the behaviour's ground layer, implement only then, GREEN unit, GREEN functional, GREEN journey, refactor. A journey/functional failure never licenses implementation on its own — descend to a ground-level failing test first. Repeat for each `when/then` path.

Run mutation testing at the end.

### 4. SECOND OPINION — review completed work

Once the work is synced and implemented, run the `second-opinion` skill process: send the change and the test-tree contract to Z.AI's GLM 5.2 and surface its independent review. A second model catches what a single perspective misses. Where it finds drift or gaps, route them back through `change`, `sync`, or `tdd`.

### 5. DONE — intent and implementation are one

All test trees in `## Test Trees` should now have passing tests and working implementation, and an independent model has reviewed the result.
