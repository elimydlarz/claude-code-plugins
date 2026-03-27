---
name: sync
description: "Complete test trees in CLAUDE.md to match implementation, then TDD any gaps. Find drift, fix it, implement it."
---

# Sync

Makes test trees in CLAUDE.md complete and truthful, then implements any gaps using the `tdd` skill. This is not a report — it's an action that leaves the project fully synced.

## When to Use

- After a significant implementation milestone
- When you suspect test trees have drifted from implementation
- Before a release or PR to verify completeness
- When onboarding to bring test trees up to date with existing code
- When the user asks "what's missing?" or "are we complete?"

## Process

### 1. LOAD TEST TREES

Read `## Requirements` in the project's CLAUDE.md. Parse each test tree — every `when/then` path is a specified behaviour.

If `## Requirements` doesn't exist or has no test trees, stop and suggest running `setup` first.

### 2. INVENTORY IMPLEMENTATION

Read the codebase to understand what's actually implemented:

- Source code — what capabilities exist?
- Existing tests — what's already covered?
- Test output — run tests and read the tree output

### 3. COMPARE: TREES → IMPLEMENTATION

For each test tree, check whether every `when/then` path has working code and a passing test.

### 4. COMPARE: IMPLEMENTATION → TREES

Check the reverse — does the implementation do things no test tree describes?

### 5. COMPLETE THE TREES

Fix the test trees in CLAUDE.md directly:

**Undocumented behaviour** (code exists, no test tree):
- Write new test trees describing the existing behaviour as operating principles
- Add them as new subsections under `## Requirements`

**Incomplete trees** (test tree doesn't capture all behaviour the implementation handles):
- Extend the tree with missing `when/then` paths

**Stale trees** (test tree for capabilities that no longer exist):
- Remove the tree from CLAUDE.md
- Confirm with user before removing if unsure

**Dead paths** (a `when/then` path in a tree that no longer reflects reality):
- Rewrite the path to match current behaviour, or remove it

After this step, `## Requirements` should be a complete and truthful description of the system — both what's already built and what still needs building.

### 6. IMPLEMENT GAPS

For each `when/then` path that has a test tree but no implementation or tests, implement it using the `tdd` skill's process:

1. Confirm test tree (already done — it's in CLAUDE.md)
2. RED (functional) — failing functional test matching the `when/then` path
3. RED (unit) — failing unit test for outermost component
4. IMPLEMENT — enough code to pass
5. GREEN — unit then functional
6. REFACTOR
7. Next gap

Work through gaps one at a time. Each gap follows the full outside-in TDD cycle.

### 7. VERIFY

After all gaps are implemented:

- Run all tests — confirm tree output matches test trees
- Re-read `## Requirements` — confirm it accurately describes the system
- If mutation testing is configured, run Stryker as final validation

## What Done Looks Like

After sync completes:

1. Every `when/then` path in `## Requirements` has a passing functional test
2. Every functional test traces to a test tree
3. No undocumented capabilities — everything the system does is specified
4. No stale trees — every tree describes something that exists
5. Test tree output reads like `## Requirements` — same language, same structure
