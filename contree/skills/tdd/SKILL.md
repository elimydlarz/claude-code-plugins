---
name: tdd
description: "Implement behaviour from test trees through outside-in, consumer-driven RED-GREEN-REFACTOR. TRIGGER when: implementing behaviour, writing code, writing tests, fixing a failing test, or closing an implementation gap from existing test trees."
---

# TDD

Implement one observable behaviour at a time through outside-in, consumer-driven TDD.

Begin with the consumer described by the current tree. Keep the implementation flat until passing tests reveal branching. Let that branching create demand for deeper units instead of predicting them in advance.

## Start

Read `TEST_TREES.md` before writing tests or implementation.

Select one observable behaviour from one tree. Its test file's hierarchy mirrors the tree verbatim.

## Test Kinds

- Journey: broad, production-like test of a curated user arc across capabilities.
- System: deep, production-like test of one capability through the whole app.
- Component: deep in-process test of one capability through the whole app, with external services replaced by test doubles.
- Adapter: test of one concrete boundary implementation against the real boundary it adapts: HTTP, CLI, database, filesystem, queue, third-party API, etc.
- Port contract: tests for an application interface such as a repository, gateway, or store; each implementation of that interface must pass those tests.
- Unit: test of one public surface on one subject; every public surface gets native unit tests, and every dependency outside the subject is mocked.

Use the test kind named by the current tree. The list classifies the current test; it is not an implementation order.

## Process

1 Write a test:
  - TDD one test at a time
  - Each test specifies an output or side-effect of the subject, given inputs and initial state
2 (RED) Test fails:
  - Observe red before changing implementation
  - Confirm that the failure comes from the behaviour the test requires
  - If a test expected to be red passes, show that it can fail before trusting it
3 (GREEN) Implement:
  - Implement only enough to make the test pass
  - Run the test and observe it pass
  - Do not add behaviour for tests that do not exist
4 (REFACTOR):
  - If you observe too much branching in test structure (e.g. an it block nested in 3 levels of describe blocks):
    - This reveals excessive conditional logic in the test subject, no matter how cleverly hidden by syntax
    - Imagine a new unit that can encapsulate some of that branching
    - Create a mock and a stub implementation for the new unit
      - Stub implementation throws NotImplemented
    - Simplify the consumer tests so they pass only when the mock is consumed correctly
    - Make the consumer call the new unit
      - Test passes but real runtime throws NotImplemented
    - TDD out the new unit (GOTO 1 but for the new unit)
      - Replacing the NotImplemented with a real implementation through the same TDD process
5 Next test: GOTO 1

In this way we implement only what is needed, outside-in, consumer-driven, using test-driven design to infrom when and what to extract.

This organic extension of test trees is part of the process, and should be reflected in test tree writes.

## Discipline

- Update the tree's labelled coverage paths immediately when creating, moving, or renaming a test or source file, and replace the corresponding `none` when coverage lands.
- Never ignore an unexpected test failure. Make the failing behaviour the current TDD work before continuing.

## Complete

TDD is complete when:

- Every affected tree path passes.
- Every mocked unit has its own tree and test file.
- Every test hierarchy mirrors its tree verbatim.
- Every coverage path names the files that exist.
- No `NotImplemented` stub remains.
