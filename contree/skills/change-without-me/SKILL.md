---
name: change-without-me
description: "Run the full Contree arc from idea to verified software without operator phase transitions: change sets expected behaviour, sync finds drift and gaps, tdd closes them, and second-opinion reviews the result. TRIGGER when: the user wants the full workflow, asks to take an idea through implementation, asks to make the project complete, or wants change/sync/tdd handled end to end."
---

# Change Without Me

Carries an idea through the full arc: from intent to contract to verified implementation. Sets expected behaviour, identifies where reality diverges, and closes every gap without pausing for review.

## When to Use

- When the user shares an idea and wants it built
- When the user wants the full cycle without manual phase transitions
- As an alternative to running `change`, `sync`, and `tdd` individually

## Process

### 1. CHANGE — set expected behaviour

Run the `change` skill process: understand the behaviour, identify the consumer, and write or modify test trees in `## Test Trees`. **Outside-in: for a broad user arc the Journey tree is the only tree to write up front; one whole-app capability starts as a Component tree.** Integration and Unit trees get added in step 3 only when a failing consumer test reveals their concern.

Do not pause for alignment — proceed directly.

### 2. SYNC — identify gaps and cruft

Run the `sync` skill process: load the test trees, inventory the implementation, compare both directions, resolve drift, identify gaps.

Do not pause to present gaps — proceed directly to implementation.

### 3. TDD — close gaps

For each gap identified by sync, run the `tdd` skill process: confirm the current tree, write and observe one RED test at its declared kind, implement only enough to make it GREEN, then refactor. When the failure reveals collaboration or one subject's public behaviour, add the Integration or Unit tree and repeat from its consumer. Repeat for each `when/then` path.

Run mutation testing at the end.

### 4. SECOND OPINION — review completed work

Once the work is synced and implemented, run the `second-opinion` skill process and surface its independent review. A second model catches what a single perspective misses. Where it finds drift or gaps, route them back through `change`, `sync`, or `tdd`.

### 5. DONE — intent and implementation are one

All test trees in `## Test Trees` should now have passing tests and working implementation, and an independent model has reviewed the result.
