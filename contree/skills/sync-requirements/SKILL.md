---
name: sync-requirements
description: "Check implementation completeness against requirement trees in CLAUDE.md. Find gaps, extend incomplete trees, fix drift."
---

# Sync Requirements

Audits the project's implementation against the requirement trees in `## Requirements` of CLAUDE.md. Finds gaps, extends incomplete trees, and ensures test coverage matches specifications.

## When to Use

- After a significant implementation milestone
- When you suspect requirements have drifted from implementation
- Before a release or PR to verify completeness
- When onboarding to check what's implemented vs specified
- When the user asks "what's missing?" or "are we complete?"

## Process

### 1. LOAD REQUIREMENTS

Read `## Requirements` in the project's CLAUDE.md. Parse each test tree — every `when/then` path is a specified behaviour.

If `## Requirements` doesn't exist or has no test trees, stop and suggest running `setup-contree` first.

### 2. INVENTORY IMPLEMENTATION

Read the codebase to understand what's actually implemented:

- Source code — what capabilities exist?
- Existing tests — what's already covered?
- Test output — run tests and read the tree output

### 3. COMPARE: REQUIREMENTS → IMPLEMENTATION

For each requirement tree, check:

- **Implemented and tested** — a `when/then` path has both working code and a passing test
- **Implemented but untested** — code exists but no test covers this path
- **Tested but failing** — test exists but doesn't pass
- **Not implemented** — no code addresses this `when/then` path
- **Partially implemented** — code exists but doesn't fully satisfy the requirement

### 4. COMPARE: IMPLEMENTATION → REQUIREMENTS

Check the reverse direction — does the implementation do things the requirements don't describe?

- **Undocumented behaviour** — code does something no requirement tree covers
- **Undocumented edge cases** — tests cover paths not in any requirement tree
- **Dead requirements** — requirement trees for capabilities that no longer exist

### 5. REPORT

Present findings organised by status:

```
## Sync Report

### Complete (implemented + tested)
- UserRegistration > when valid details > then account created ✓
- UserRegistration > when duplicate email > then rejected ✓

### Gaps (in requirements, not implemented)
- InvoiceGeneration > when order has no line items > then rejected
  → No code handles empty line items

### Untested (implemented, no test)
- PaymentProcessing > when payment succeeds > then receipt generated
  → Code exists in PaymentService but no functional or unit test

### Undocumented (implemented, not in requirements)
- RateLimiting applied to all API endpoints
  → Middleware exists but no requirement tree describes it

### Stale (in requirements, capability removed)
- LegacyExport > when CSV requested > then export generated
  → Export feature was removed in recent refactor
```

### 6. FIX

Based on the report, take action:

**For gaps** (requirement exists, no implementation):
- These are TODO items for the `tdd` skill
- Note them but don't implement — the user decides priority

**For untested paths** (implementation exists, no test):
- Write the missing tests using the `tdd` skill's process
- Start with functional test, then unit tests

**For undocumented behaviour** (implementation exists, no requirement):
- Add requirement trees to `## Requirements` in CLAUDE.md
- Write trees that describe the existing behaviour as operating principles

**For stale requirements** (requirement exists, capability removed):
- Remove the requirement tree from CLAUDE.md
- Confirm with user before removing if unsure

**For incomplete trees** (requirement tree doesn't capture all the behaviour the implementation handles):
- Extend the tree with missing `when/then` paths
- Update CLAUDE.md

### 7. VERIFY

After fixes:
- Run all tests — confirm tree output matches updated requirements
- Re-read `## Requirements` — confirm it accurately describes the system
- If mutation testing is configured, run it to validate test quality

## What Good Sync Looks Like

After a successful sync:

1. Every `when/then` path in `## Requirements` has a passing functional test
2. Every functional test traces to a requirement tree
3. No undocumented capabilities (everything the system does is specified)
4. Test tree output (when run) reads like `## Requirements` — same language, same structure
5. Requirement trees describe operating principles, not implementation details
