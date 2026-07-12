---
name: sync
description: "Identify and resolve drift between operator intention, test trees, tests, implementation, and the mental model. TRIGGER when: the user asks about drift, gaps, staleness, completeness, whether trees match code, whether the project is in sync, what is missing, or what should be removed."
---

# Sync

## Contract

`TEST_TREES.md` expresses what the operator expects from the software. It is the coding agent's contract with the operator. Operator intention is the guiding principle.

Read `TEST_TREES.md`, `MENTAL_MODEL.md`, tests, production code, and test commands. If TEST_TREES.md does not exist or contains no trees, stop and suggest running `setup` first. Run the full suite before reviewing; every failure is drift.

Requirements use these exact EARS forms:

```text
then <ubiquitous outcome>

while <precondition>
  then <outcome>

when <trigger>
  then <outcome>

where <optional feature>
  then <outcome>

if <unwanted condition>
  then <recovery outcome>
```

Causal behaviour nests beneath the outcome that makes it possible. Review each `then`, `and`, and `but` assertion as a leaf.

## Review

Partition complete, non-overlapping work across subagents. Reconcile their evidence yourself.

Delegate every leaf across the subagents.

1. **Every tree leaf**
   - Establish that its test exists.
   - Establish that the test file's describe/it hierarchy mirrors the tree verbatim and expresses the leaf's intention.
   - Run the test and establish that the implementation passes the test.
   - Establish that the implementation fulfils the intention shared by the leaf and test: the spirit, not only the literal assertion.
   - Verify every labelled `src`, `domain`, `use-case`, `adapter`, `component`, `system`, and `journey` path against the filesystem. Every `none` is a gap to close immediately.

2. **All production code**
   - Give subagents complete, non-overlapping areas of production code.
   - Find every observable behaviour or side effect that `TEST_TREES.md` does not express.

3. **Every mental-model heading**
   - Give each of the seven headings a separate subagent review.
   - Decide whether its representation of the codebase is accurate and useful.
   - Decide whether the codebase honours that representation.

At Domain, Use-case, and Port public seams, every observable branch has a matching EARS path and every path has matching behaviour. Internal control flow is not itself a requirement. Evaluate YAGNI separately when the reverse code review finds behaviour without a consumer.

Coverage overlaps intentionally. A higher-layer test never replaces native coverage of a substantive unit revealed by TDD. A substantive unit without a tree and test at its natural lowest layer is a gap to close immediately. Retain higher-layer coverage, and test the behaviour at every applicable layer where its seam can observe it. Do not invent inner units or layers before TDD reveals them.

## Resolve

Resolve every finding now using the rules, mental model, trees, tests, code evidence, and your own judgment.

- Use `change` when legitimate operator-expected behaviour is absent from the contract or a tree fails to express established operator intention.
- Use `tdd` for missing or failing tests, missing implementation, missing native coverage, and implementation that fails the intention expressed by a leaf and test.
- Remove implementation that has no consumer and is not part of operator intention.
- Tighten mental-model representations that do not fit the codebase; bring code that violates a valid representation back into alignment.

Escalate only a consequential, genuinely under-determined choice that the rules, mental model, trees, tests, code, and operator intention cannot settle.

## Done

Run every affected test and the full suite. Sync is complete only when:

- every tree leaf has a faithful passing test and fulfilling implementation
- every test file reifies exactly one tree and its hierarchy mirrors the tree verbatim
- every applicable layer has its intentional overlapping coverage
- no observable implementation lies outside the trees
- every coverage path exists and no `none` remains
- the mental model accurately and usefully represents the codebase, and the codebase honours it
- the full suite is green with no skipped drift

Once the project is in sync, suggest `second-opinion` for an independent review.
