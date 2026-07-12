#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/tdd/SKILL.md"

@test "when TDD starts then the current tree is read and development proceeds outside-in from its consumer" {
  run cat "$SKILL"
  assert_output --partial 'Read `TEST_TREES.md`'
  assert_output --partial "one observable behaviour"
  assert_output --partial "outside-in"
  assert_output --partial "consumer-driven"
}

@test "when choosing a test kind then the concise test-kind definitions are present without prescribing an order" {
  run cat "$SKILL"
  assert_output --partial "Journey: broad, production-like test of a curated user arc across capabilities."
  assert_output --partial "System: deep, production-like test of one capability through the whole app."
  assert_output --partial "Component: deep in-process test of one capability through the whole app, with external services replaced by test doubles."
  assert_output --partial "Adapter: test of one concrete boundary implementation against the real boundary it adapts: HTTP, CLI, database, filesystem, queue, third-party API, etc."
  assert_output --partial "Port contract: tests for an application interface such as a repository, gateway, or store; each implementation of that interface must pass those tests."
  assert_output --partial "Unit: test of one public surface on one subject; every public surface gets native unit tests, and every dependency outside the subject is mocked."
  assert_output --partial "not an implementation order"
}

@test "when implementing the selected behaviour then the exact recursive TDD process is given" {
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

@test "when implementing the selected behaviour then one test is run at a time and only enough real behaviour is implemented" {
  run cat "$SKILL"
  assert_output --partial "Write and run one test at a time."
  assert_output --partial "Implement only enough real behaviour to pass the current test."
}

@test "when the passing test branches then the branching creates demand for an imagined unit" {
  run cat "$SKILL"
  assert_output --partial "too much branching in the test or tree"
  assert_output --partial "some of that branching"
  assert_output --partial "Do not predict units"
}

@test "when the unit is extracted then the mock passes consumer tests and the stub makes running code fail loudly" {
  run cat "$SKILL"
  assert_output --partial "Create a mock for the unit."
  assert_output --partial 'Create a stub implementation that throws `NotImplemented`.'
  assert_output --partial "pass only when the mock is consumed correctly"
  assert_output --partial "Make the consumer call the unit."
  assert_output --partial "consumer tests pass"
  assert_output --partial 'running the code throws `NotImplemented`'
  assert_output --partial "visible reason"
}

@test "when the mocked unit becomes the subject then it receives a tree and the process restarts" {
  run cat "$SKILL"
  assert_output --partial "The passing mock and throwing stub are the signal to TDD the new unit."
  assert_output --partial "Add its tree from the behaviour the consumer requires."
  assert_output --partial "Return to step 1 with that unit."
  assert_output --partial "Replace the throwing stub"
}

@test "when a test is expected to be red then its failure is observed before implementation" {
  run cat "$SKILL"
  assert_output --partial "Observe RED before changing implementation."
  assert_output --partial "show that it can fail before trusting it"
}

@test "when a test is green then refactoring stays local and branching drives extraction" {
  run cat "$SKILL"
  assert_output --partial "Refactor only the behaviour just implemented."
  assert_output --partial "Duplication is a hint"
  assert_output --partial "branching under different conditions"
}

@test "when files change then tree coverage paths stay current" {
  run cat "$SKILL"
  assert_output --partial "Update the tree's labelled coverage paths immediately"
  assert_output --partial 'replace the corresponding `none`'
}

@test "when TDD is complete then trees tests implementation are complete and no throwing stub remains" {
  run cat "$SKILL"
  assert_output --partial "Every affected tree path passes."
  assert_output --partial "Every mocked unit has its own tree and test file."
  assert_output --partial "Every test hierarchy mirrors its tree verbatim."
  assert_output --partial 'No `NotImplemented` stub remains.'
}

@test "the narrow TDD skill does not explain architecture or other skills" {
  run grep -Ei 'hexagonal|skills/(change|sync|setup|workflow)|`(change|sync|setup|workflow)`' "$SKILL"
  assert_failure
}
