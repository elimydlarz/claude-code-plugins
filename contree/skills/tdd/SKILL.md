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

## Unit Tests: Intentional External Impact and Implementation Details

Before setting up dependency mocks or assertions, identify each interaction as either an intentional external impact or an incidental implementation detail.

The operator intends an external impact when the interaction itself must happen, such as publishing a message or changing an external record. Set up the mock to record the interaction. Assert that it was called correctly with the meaningful arguments.

The interaction is an incidental implementation detail when it is only how the current implementation produces the result under test. Set up the mock to behave realistically: it provides the needed response only for the exact invocation and arguments that work in reality. Do not assert against the interaction. Assert the subject's observable result.

The realistic setup means an incorrect interaction cannot make the test pass, while the absence of an interaction assertion keeps the implementation detail out of the contract.

## Process

1 Write a test
2 (RED) Test goes red
3 (GREEN) Implement to green the test
4 (REFACTOR) Observe too much branching in the test or tree - too many conditions
5 Imagine a unit that can encapsulate some of that branching
6 Create a mock and a stub implementation for that unit
7 Make the consumer call the unit; the mock passes the tests while the stub throws NotImplemented
8 TDD out the new unit (GOTO 1 but this time for the new unit)

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

Observe whether the passing test or its tree contains too much branching under different conditions.

Do not predict units. Wait until the conditions in front of you show that one unit could own some of that branching.

When that happens:

1. Create a mock for the unit.
2. Give the mock a visible reason for existing.
3. Create a stub implementation that throws `NotImplemented`.
4. Simplify the consumer tests so they pass only when the mock is consumed correctly.
5. Make the consumer call the unit.

Now the consumer tests pass because they use the mock, but running the code throws `NotImplemented` when it reaches the stub. That is intentional: the consumer needs the new unit, but the unit does not work yet.

## TDD the New Unit

The passing mock and throwing stub are the signal to TDD the new unit.

1. Add its tree from the behaviour the consumer requires.
2. Return to step 1 with that unit.
3. Replace the throwing stub by making the unit's tests pass.

That is the whole recursion: a mock makes the consumer tests pass, a stub makes the unfinished unit fail loudly, and the TDD loop moves to that unit.

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
- No `NotImplemented` stub remains.
