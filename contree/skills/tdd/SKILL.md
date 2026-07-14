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

## Unit Test Mocks

Before setting up mocks for a test, understand what that test asserts: its observable result and any intentional side effects. Everything else the subject does to produce that behaviour is an implementation detail.

A side effect is an external impact the operator expects this test to guarantee. Set up the mock to record the interaction. Assert that it was called correctly with the meaningful arguments.

An implementation detail is an interaction the test needs only because the subject currently works that way. Set up the mock to behave realistically only for the exact invocation and arguments. Do not assert against the interaction. Assert the subject's observable result. An incorrect interaction must not make the test pass.

## Process

1 Write a test
2 (RED) Test goes red
3 (GREEN) Implement to green the test
4 (REFACTOR) Observe too much branching in the test or tree - too many conditions
5 Imagine a unit that can encapsulate some of that branching
6 Create a mock and a stub implementation for that unit
7 Make the consumer call the unit; the mock passes the tests while the stub throws NotImplemented
8 TDD out the new unit (GOTO 1 but this time for the new unit)

Write and run one test at a time. Each test specifies an output or side effect of the subject given its public input and initial state. Observe RED before changing implementation. Confirm that the failure comes from the required behaviour. If a test expected to be red passes, show that it can fail before trusting it.

Implement only enough real behaviour to pass the current test. Run it and observe GREEN. Do not add behaviour for tests that do not exist.

During REFACTOR, inspect the passing test and its tree for too much branching in the test or tree under different conditions. Branching creates demand for a unit that encapsulates some of that branching. Do not predict units before that demand is observable.

Create a mock for the unit. Give the mock a visible reason naming the branching it replaces. Create a stub implementation that throws `NotImplemented`. Simplify the consumer tests so they pass only when the mock is consumed correctly. Make the consumer call the unit. The consumer tests pass through the mock while running the code throws `NotImplemented`.

The passing mock and throwing stub are the signal to TDD the new unit. Add its tree from the behaviour the consumer requires. Return to step 1 with that unit. Replace the throwing stub through its own RED-GREEN-REFACTOR cycle.

Refactor only the behaviour just implemented. Duplication is a hint; branching under different conditions is the reason to extract a unit.

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
