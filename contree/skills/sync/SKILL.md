---
name: sync
description: "Identify gaps and cruft — where intent and implementation have drifted apart. Compares test trees against code in both directions, then hands gaps to tdd. TRIGGER when: the user asks about drift, gaps, staleness, or completeness — including loose phrasings like 'check for drift', 'audit the project', 'something feels off', 'is this in sync', 'review the trees vs the code', 'propose fixes for drift', or 'what's missing?'."
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

- Source code — what capabilities exist? What domain objects, use-cases, ports, adapters?
- Existing tests at each layer (`*.domain.test.*`, `*.use-case.test.*`, `*.adapter.test.*`, `*.system.test.*`) — what's already covered?
- **Describe/it hierarchy in each test file** — parse the test source (`describe(`, `it(`, `test(`, `context(`, or the language's equivalent). This is the framework-agnostic comparison point: the hierarchy must mirror its tree verbatim.
- Test output — where the framework supports nested output, run tests and read the tree reporter output. Supplementary to describe/it parsing.

### 3. COMPARE: TREES → IMPLEMENTATION

For each test tree, check four things:

1. **Path parity per category** — for each labelled pair in the tree's parenthesised paths (`src`, `unit`, `integration`, `functional`), verify the named file exists on the filesystem. A tree that names `src/foo.ts` when the file lives at `src/bar.ts` (or nowhere) is drift. Any category declared `none` is surfaced as an explicit gap for the user to resolve — intentional-but-open, awaiting coverage.
2. **Describe/it parity** — every path in the tree appears as a describe/it in the test file, and every describe/it in the test file appears as a path in the tree. Verbatim match.
3. **Test passes** — the tests exist and are green.
4. **Branch parity** (Domain, Use-case, Port-contract) — every observable branch in the unit's code corresponds to a tree path, and every path corresponds to a branch. YAGNI plus the code-shaped-tree rule makes this tight.

### 4. COMPARE: IMPLEMENTATION → TREES

Check the reverse — does the implementation do things no test tree describes? At Domain, Use-case, and Port-contract, any branch without a corresponding tree path is drift. At Adapter and System, any observable behaviour at the seam without a tree is drift.

### 5. RESOLVE DRIFT

**Never resolve drift unilaterally.** Every case below requires a concrete user decision before any edit — even when the resolution seems obvious (e.g. "the function is clearly YAGNI, just delete it"). Drift is where intent and implementation disagree; silently picking a side destroys the contract this skill exists to protect. Present the drift, present the options, ask, then act on the answer.

**Implementation missing for a tree path** (test tree exists, no code):
- Flag as a gap to implement. These are the priority.

**Implementation exists without a tree** (code exists, no test tree):
- Present the two options to the user, with a quick read of the evidence: (a) the implementation is accidental scope creep → remove it, or (b) it's a legitimate capability → write a tree for it. Do not choose. Ask.

**Path drift** (a tree names a file path that does not exist on the filesystem):
- Flag as drift. The path may be wrong (update the tree), the file may have been moved (update the tree), or the implementation is missing (hand to `tdd`). Present to the user and ask.

**Stale trees** (test tree for capabilities that no longer exist):
- Present to the user before removing. Ask whether the capability should come back (write/restore it) or the tree is truly obsolete (remove it).

**Dead paths** (a `when/then` path that no longer reflects reality):
- Present to the user. The path may need updating, or the implementation may be wrong — ask which.

**Describe/it drift** (test file's describe/it hierarchy disagrees with its tree):
- Present both the tree text and the describe/it hierarchy to the user. Ask which is authoritative — update the test to match the tree, or update the tree to match the test. Do not pick.

After this step, test trees and implementation intent should be aligned, and the user has approved every change.

### 6. IMPLEMENT GAPS

For each tree with no test file (or no passing tests), suggest the user runs `tdd` to implement it. Present the gaps so they can prioritise.

### 7. VERIFY

After all gaps are implemented:

- Run all tests at every layer — confirm tree output matches `## Test Trees`
- Re-read `## Test Trees` — confirm it accurately describes the system
- If mutation testing is configured, run Stryker against Domain + Use-case as final validation

## What Done Looks Like

After sync completes:

1. Every tree in `## Test Trees` has a test file; every `when/then` path has a passing test at that tree's layer
2. Every test file reifies exactly one tree
3. No undocumented capabilities — everything the system does is specified
4. No stale trees — every tree describes something that exists
5. Test output reads like `## Test Trees` — same language, same structure
