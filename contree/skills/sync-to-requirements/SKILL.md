---
name: sync-to-requirements
description: "Complete requirement trees in CLAUDE.md to match implementation, then TDD any gaps. Find drift, fix it, implement it."
---

# Sync to Requirements

Makes requirement trees in CLAUDE.md complete and truthful, then implements any gaps using the `tdd` skill. This is not a report — it's an action that leaves the project fully synced.

## When to Use

- After a significant implementation milestone
- When you suspect requirements have drifted from implementation
- Before a release or PR to verify completeness
- When onboarding to bring requirements up to date with existing code
- When the user asks "what's missing?" or "are we complete?"

## Process

### 1. LOAD REQUIREMENTS

Read `## Requirements` in the project's CLAUDE.md. Parse each test tree — every `when/then` path is a specified behaviour.

If `## Requirements` doesn't exist or has no test trees, stop and suggest running `setup-contree` first.

### 2. PLAN TEST DECOMPOSITION

For each requirement tree, plan how it decomposes into functional and unit tests using consumer-driven thinking:

**Functional tests** describe consumer-visible behaviour. Use the consumer's vocabulary — if the consumer says "register", the test says "registers", not "calls POST /api/users".

**Unit tests** describe a single component's responsibilities. Each component is consumed by the layer above — write from the perspective of *its* consumer.

For each requirement tree:

1. **Identify the consumer.** Who or what consumes this behaviour? A user? An API client? Another module?
2. **Map `when/then` paths to functional tests.** Each path in the requirement tree becomes a functional test case. No implementation details — just what the consumer observes.
3. **Decompose inward to unit tests.** Ask: what internal components need to exist to make this work? Each component gets unit tests showing what it does when called by its consumer. Mock collaborators — each unit test describes one component's responsibilities, not the whole chain.
4. **Stop decomposing when it's obvious.** Not every internal function needs unit tests. If a component's behaviour is trivial, skip it.

Every `then` in the requirement tree should be traceable through the functional and unit test plan.

### 3. INVENTORY IMPLEMENTATION

Read the codebase to understand what's actually implemented:

- Source code — what capabilities exist?
- Existing tests — what's already covered?
- Test output — run tests and read the tree output

### 3. COMPARE: REQUIREMENTS → IMPLEMENTATION

For each requirement tree, check whether every `when/then` path has working code and a passing test.

### 4. COMPARE: IMPLEMENTATION → REQUIREMENTS

Check the reverse — does the implementation do things no requirement tree describes?

### 5. COMPLETE THE TREES

Fix the requirement trees in CLAUDE.md directly:

**Undocumented behaviour** (code exists, no requirement tree):
- Write new requirement trees describing the existing behaviour as operating principles
- Add them as new subsections under `## Requirements`

**Incomplete trees** (requirement tree doesn't capture all behaviour the implementation handles):
- Extend the tree with missing `when/then` paths

**Stale requirements** (requirement tree for capabilities that no longer exist):
- Remove the tree from CLAUDE.md
- Confirm with user before removing if unsure

**Dead paths** (a `when/then` path in a tree that no longer reflects reality):
- Rewrite the path to match current behaviour, or remove it

After this step, `## Requirements` should be a complete and truthful description of the system — both what's already built and what still needs building.

### 6. IMPLEMENT GAPS

For each `when/then` path that has a requirement tree but no implementation or tests, implement it using the `tdd` skill's process:

1. Confirm requirement tree (already done — it's in CLAUDE.md)
2. RED (functional) — failing functional test matching the `when/then` path
3. RED (unit) — failing unit test for outermost component
4. IMPLEMENT — enough code to pass
5. GREEN — unit then functional
6. REFACTOR
7. Next gap

Work through gaps one at a time. Each gap follows the full outside-in TDD cycle.

### 7. VERIFY

After all gaps are implemented:

- Run all tests — confirm tree output matches requirement trees
- Re-read `## Requirements` — confirm it accurately describes the system
- If mutation testing is configured, run Stryker as final validation

## What Done Looks Like

After sync-to-requirements completes:

1. Every `when/then` path in `## Requirements` has a passing functional test
2. Every functional test traces to a requirement tree
3. No undocumented capabilities — everything the system does is specified
4. No stale requirements — every tree describes something that exists
5. Test tree output reads like `## Requirements` — same language, same structure
