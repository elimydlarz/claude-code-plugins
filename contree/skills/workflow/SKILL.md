---
name: workflow
description: "End-to-end: idea → test trees → implementation. Runs change, sync, and tdd in sequence without pausing."
---

# Workflow

Takes a behaviour change from idea to working software. Runs the full contree sequence without pausing for review.

## When to Use

- When the user shares an idea and wants it built
- When the user wants the full cycle without manual phase transitions
- As an alternative to running `change`, `sync`, and `tdd` individually

## Process

### 1. CHANGE

Run the `change` skill process: understand the behaviour, identify the consumer, write or modify test trees in `## Requirements`, decompose into functional and unit layers.

Do not pause for alignment — proceed directly.

### 2. SYNC

Run the `sync` skill process: load the test trees, inventory the implementation, compare both directions, resolve drift, identify gaps.

Do not pause to present gaps — proceed directly to implementation.

### 3. TDD

For each gap identified by sync, run the `tdd` skill process: confirm test tree, RED functional, RED unit, implement, GREEN unit, GREEN functional, refactor. Repeat for each `when/then` path.

Run mutation testing at the end.

### 4. DONE

All test trees in `## Requirements` should now have passing tests and working implementation.
