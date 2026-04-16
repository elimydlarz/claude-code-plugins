---
name: sync
description: "Identify gaps and cruft — where intent and implementation have drifted apart. Compares test trees against code in both directions, then hands gaps to tdd. TRIGGER when: the user asks about drift, gaps, or whether requirements are complete."
---

# Sync

Finds where the contract has drifted from reality. Compares the trees in `## Test Trees` against implementation in both directions — surfacing gaps (intent without code), cruft (code without intent), and staleness (trees that no longer reflect the system). Resolves drift with the user, then hands gaps to `tdd`.

## When to Use

- After a significant implementation milestone
- When you suspect test trees have drifted from implementation
- Before a release or PR to verify completeness
- When onboarding to bring test trees up to date with existing code
- When the user asks "what's missing?" or "are we complete?"

## Process

### 1. LOAD TEST TREES

Read `## Test Trees` in the project's CLAUDE.md. Parse each tree — every `when/then` path is a specified behaviour.

If `## Test Trees` doesn't exist or has no trees, stop and suggest running `setup` first.

### 2. INVENTORY IMPLEMENTATION

Read the codebase to understand what's actually implemented:

- Source code — what capabilities exist?
- Existing tests — what's already covered?
- Test output — run tests and read the tree output

### 3. COMPARE: TREES → IMPLEMENTATION

For each test tree, check whether every `when/then` path has working code and a passing test.

### 4. COMPARE: IMPLEMENTATION → TREES

Check the reverse — does the implementation do things no test tree describes?

### 5. RESOLVE DRIFT

**Implementation missing for a tree path** (test tree exists, no code):
- Flag as a gap to implement. These are the priority.

**Implementation exists without a tree** (code exists, no test tree):
- Discuss with the user. The implementation may be accidental scope creep that should be removed, or it may be a legitimate capability that needs a tree. Don't assume either way.

**Stale trees** (test tree for capabilities that no longer exist):
- Discuss with the user before removing.

**Dead paths** (a `when/then` path that no longer reflects reality):
- Discuss with the user. The path may need updating or the implementation may be wrong.

After this step, test trees and implementation intent should be aligned.

### 6. IMPLEMENT GAPS

For each `when/then` path that has a test tree but no implementation or tests, suggest the user runs `tdd` to implement it. Present the gaps so they can prioritise.

### 7. VERIFY

After all gaps are implemented:

- Run all tests — confirm tree output matches test trees
- Re-read `## Requirements` — confirm it accurately describes the system
- If mutation testing is configured, run Stryker as final validation

## What Done Looks Like

After sync completes:

1. Every tree in `## Test Trees` has a test file; every `when/then` path has a passing test at that tree's layer
2. Every test file reifies exactly one tree
3. No undocumented capabilities — everything the system does is specified
4. No stale trees — every tree describes something that exists
5. Test output reads like `## Test Trees` — same language, same structure
