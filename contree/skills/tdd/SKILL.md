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

If no tree covers the behaviour, stop. Do not invent the contract while implementing it.

## Test Kinds

- Journey: broad, production-like test of a curated user arc across capabilities.
- System: deep, production-like test of one capability through the whole app.
- Component: deep in-process test of one capability through the whole app, with external services replaced by test doubles.
- Adapter: test of one concrete boundary implementation against the real boundary it adapts: HTTP, CLI, database, filesystem, queue, third-party API, etc.
- Port contract: tests for an application interface such as a repository, gateway, or store; each implementation of that interface must pass those tests.
- Unit: test of one public surface on one subject; every public surface gets native unit tests, and every dependency outside the subject is mocked.

Use the test kind named by the current tree. The list classifies the current test; it is not an implementation order.

## Process

1 Write a test
2 (RED) Test goes red
3 (GREEN) Implement to green the test
4 (REFACTOR) Observe branching in the test - different behaviour under different conditions
5 Imagine a unit that can encapsulate the branching
6 Mock that unit and simplify tests such that they only work when mock is consumed correctly
7 Consume the mock in implementation to pass the tests
8 TDD out the mocked unit (GOTO 1 but this time for the mocked unit)

## Write a Test

Write and run one test at a time.

The test describes the selected observable behaviour at the current subject.

## RED

Observe RED before changing implementation.

Confirm that the failure comes from the behaviour the test requires. If a test expected to be red passes, show that it can fail before trusting it.

## GREEN

Implement only enough real behaviour to pass the current test.

Run the test and observe it pass. Do not add behaviour for tests that do not exist.

## REFACTOR

Observe whether the passing test contains different behaviour under different conditions.

Only observed branching creates demand for a new unit. Do not predict units or extract trivial forwarding.

When one unit can encapsulate the branching:

1. Mock that unit.
2. Give the mock a visible reason for existing.
3. Simplify the consumer tests so they pass only when the mock is consumed correctly.
4. Change the consumer implementation to consume it.
5. Keep the consumer tests green.

The mock now shows what the new unit must do.

## Repeat for the Mocked Unit

The mock names the next subject.

1. Add a tree for the behaviour expected from that mock.
2. Repeat from step 1 with that unit.
3. When its tests pass, use the real unit in production.

Production uses the real unit; the consumer test keeps the mock.

## Discipline

- Refactor only the behaviour just implemented.
- Duplication is a hint; branching under different conditions is the reason to imagine a unit.
- Keep every existing consumer test that still describes supported behaviour.
- Update the tree's labelled coverage paths immediately when creating, moving, or renaming a test or source file, and replace the corresponding `none` when coverage lands.
- Never ignore an unexpected test failure. Make the failing behaviour the current TDD work before continuing.

## Complete

TDD is complete when:

- Every affected tree path passes.
- Every mocked unit has its own tree and test file.
- Every test hierarchy mirrors its tree verbatim.
- Every coverage path names the files that exist.
- Production consumes real units; mocks remain in tests.
