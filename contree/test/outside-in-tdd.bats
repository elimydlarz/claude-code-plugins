#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/tdd/SKILL.md"

@test "when TDD starts then the current test tree is read before tests or implementation" {
  run cat "$SKILL"
  assert_output --partial 'Read `TEST_TREES.md`'
  assert_output --partial "before writing tests or implementation"
}

@test "when TDD starts and one observable behaviour is selected" {
  run cat "$SKILL"
  assert_output --partial "Select one observable behaviour"
}

@test "when TDD starts and development proceeds outside-in from that behaviour's consumer" {
  run cat "$SKILL"
  assert_output --partial "outside-in"
  assert_output --partial "consumer-driven"
}

@test "when choosing a test kind then Journey, System, Component, Adapter, Port contract, and Unit are defined in the same concise terms as the session rules" {
  run cat "$SKILL"
  assert_output --partial "Journey: broad, production-like test of a curated user arc across capabilities."
  assert_output --partial "System: deep, production-like test of one capability through the whole app."
  assert_output --partial "Component: deep in-process test of one capability through the whole app, with external services replaced by test doubles."
  assert_output --partial "Adapter: test of one concrete boundary implementation against the real boundary it adapts"
  assert_output --partial "Port contract: tests for an application interface"
  assert_output --partial "Unit: test of one public surface on one subject"
  refute_output --partial "Integration:"
}

@test "when choosing a test kind and the test kind describes the current test rather than a predetermined implementation order" {
  run cat "$SKILL"
  assert_output --partial "not an implementation order"
}

@test "when setting up mocks for a Unit test then the agent first identifies the observable result and intentional side effects that the test asserts" {
  run cat "$SKILL"
  assert_output --partial "Before setting up mocks for a test, understand what that test asserts"
  assert_output --partial "its observable result and any intentional side effects"
}

@test "when setting up mocks for a Unit test and treats other dependency interactions as implementation details of how the subject currently produces that behaviour" {
  run cat "$SKILL"
  assert_output --partial "Everything else the subject does to produce that behaviour is an implementation detail."
}

@test "when setting up mocks for a Unit test when an intentional side effect is part of the behaviour under test then the mock records the interaction" {
  run cat "$SKILL"
  assert_output --partial "Set up the mock to record the interaction"
}

@test "when setting up mocks for a Unit test when an intentional side effect is part of the behaviour under test and the test asserts that it is called correctly with meaningful arguments" {
  run cat "$SKILL"
  assert_output --partial "Assert that it was called correctly with the meaningful arguments"
}

@test "when setting up mocks for a Unit test when a dependency interaction is an implementation detail then the mock responds only to the exact realistic invocation and arguments" {
  run cat "$SKILL"
  assert_output --partial "Set up the mock to behave realistically"
  assert_output --partial "only for the exact invocation and arguments"
}

@test "when setting up mocks for a Unit test when a dependency interaction is an implementation detail and the interaction is not asserted" {
  run cat "$SKILL"
  assert_output --partial "Do not assert against the interaction."
}

@test "when setting up mocks for a Unit test when a dependency interaction is an implementation detail and the test asserts the subject's observable result, so an incorrect interaction cannot make the test pass" {
  run cat "$SKILL"
  assert_output --partial "Assert the subject's observable result."
  assert_output --partial "An incorrect interaction must not make the test pass."
}

@test "when implementing the selected behaviour then the exact process is write a test, observe RED, implement to GREEN, observe too much branching in the test or tree during REFACTOR, imagine a unit that encapsulates some of that branching, create its mock and throwing stub, make the consumer call it, and TDD the new unit by returning to the first step" {
  run cat "$SKILL"
  assert_output --partial "1 Write a test"
  assert_output --partial "2 (RED) Test goes red"
  assert_output --partial "3 (GREEN) Implement to green the test"
  assert_output --partial "4 (REFACTOR) Observe too much branching in the test or tree - too many conditions"
  assert_output --partial "5 Imagine a unit that can encapsulate some of that branching"
  assert_output --partial "6 Create a mock and a stub implementation for that unit"
  assert_output --partial "7 Make the consumer call the unit; the mock passes the tests while the stub throws NotImplemented"
  assert_output --partial "8 TDD out the new unit (GOTO 1 but this time for the new unit)"
}

@test "when implementing the selected behaviour and only one test is written and run at a time" {
  run cat "$SKILL"
  assert_output --partial "Write and run one test at a time."
}

@test "when implementing the selected behaviour and only enough real behaviour to pass that test is implemented" {
  run cat "$SKILL"
  assert_output --partial "Implement only enough real behaviour to pass the current test."
}

@test "when the passing test or its tree contains too much branching under different conditions then a unit that can encapsulate that branching is imagined" {
  run cat "$SKILL"
  assert_output --partial "too much branching in the test or tree"
  assert_output --partial "unit that encapsulates some of that branching"
}

@test "when the passing test or its tree contains too much branching under different conditions and the unit is not designed before the branching is observed" {
  run cat "$SKILL"
  assert_output --partial "Do not predict units"
}

@test "when the imagined unit is mocked then the consumer tests are simplified so they pass only when the mock is consumed correctly" {
  run cat "$SKILL"
  assert_output --partial "pass only when the mock is consumed correctly"
}

@test "when the imagined unit is mocked and the mock visibly names why it exists" {
  run cat "$SKILL"
  assert_output --partial "visible reason"
}

@test "when the imagined unit is mocked and a stub implementation of the unit throws NotImplemented" {
  run cat "$SKILL"
  assert_output --partial 'Create a stub implementation that throws `NotImplemented`.'
}

@test "when the imagined unit is mocked and the consumer implementation calls the unit" {
  run cat "$SKILL"
  assert_output --partial "Make the consumer call the unit."
}

@test "when the imagined unit is mocked and the consumer tests pass through the mock while running the code fails at the throwing stub" {
  run cat "$SKILL"
  assert_output --partial "consumer tests pass"
  assert_output --partial 'running the code throws `NotImplemented`'
}

@test "when the mocked unit becomes the TDD subject then the passing mock and throwing stub signal that the new unit must be TDDed" {
  run cat "$SKILL"
  assert_output --partial "The passing mock and throwing stub are the signal to TDD the new unit."
}

@test "when the mocked unit becomes the TDD subject and its own tree describes the behaviour its consumer requires before its first test" {
  run cat "$SKILL"
  assert_output --partial "Add its tree from the behaviour the consumer requires."
}

@test "when the mocked unit becomes the TDD subject and the TDD process returns to step 1 with that unit as the new subject" {
  run cat "$SKILL"
  assert_output --partial "Return to step 1 with that unit."
}

@test "when the mocked unit becomes the TDD subject and its implementation replaces the throwing stub as its tests are made green" {
  run cat "$SKILL"
  assert_output --partial "Replace the throwing stub"
}

@test "when a test is expected to be red then the failure is observed before implementation" {
  run cat "$SKILL"
  assert_output --partial "Observe RED before changing implementation."
}

@test "when a test is expected to be red and an incidentally passing test is shown to fail before it is trusted" {
  run cat "$SKILL"
  assert_output --partial "show that it can fail before trusting it"
}

@test "when a test is green then refactoring is limited to the behaviour just implemented" {
  run cat "$SKILL"
  assert_output --partial "Refactor only the behaviour just implemented."
}

@test "when a test is green and duplication is treated as a hint while branching under different conditions is the reason to imagine a unit" {
  run cat "$SKILL"
  assert_output --partial "Duplication is a hint"
  assert_output --partial "branching under different conditions"
}

@test "when tests and source files are created, moved, or renamed then the tree's labelled coverage paths are updated immediately" {
  run cat "$SKILL"
  assert_output --partial "Update the tree's labelled coverage paths immediately"
}

@test "when tests and source files are created, moved, or renamed and a covered \"none\" value is replaced with the created path" {
  run cat "$SKILL"
  assert_output --partial 'replace the corresponding `none`'
}

@test "when TDD is complete then every affected tree path passes" {
  run cat "$SKILL"
  assert_output --partial "Every affected tree path passes."
}

@test "when TDD is complete and every mocked unit has its own tree and test file" {
  run cat "$SKILL"
  assert_output --partial "Every mocked unit has its own tree and test file."
}

@test "when TDD is complete and test hierarchies mirror their trees verbatim" {
  run cat "$SKILL"
  assert_output --partial "Every test hierarchy mirrors its tree verbatim."
}

@test "when TDD is complete and no NotImplemented stub remains" {
  run cat "$SKILL"
  assert_output --partial 'No `NotImplemented` stub remains.'
}
