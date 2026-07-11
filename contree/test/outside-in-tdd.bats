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
  assert_output --partial "4 (REFACTOR) Observe branching in the test - different behaviour under different conditions"
  assert_output --partial "5 Imagine a unit that can encapsulate the branching"
  assert_output --partial "6 Mock that unit and simplify tests such that they only work when mock is consumed correctly"
  assert_output --partial "7 Consume the mock in implementation to pass the tests"
  assert_output --partial "8 TDD out the mocked unit (GOTO 1 but this time for the mocked unit)"
}

@test "when implementing the selected behaviour then one test is run at a time and only enough real behaviour is implemented" {
  run cat "$SKILL"
  assert_output --partial "Write and run one test at a time."
  assert_output --partial "Implement only enough real behaviour to pass the current test."
}

@test "when the passing test branches then the branching creates demand for an imagined unit" {
  run cat "$SKILL"
  assert_output --partial "different behaviour under different conditions"
  assert_output --partial "Only observed branching creates demand for a new unit."
  assert_output --partial "Do not predict units"
}

@test "when the imagined unit is mocked then consumer tests pass only when the mock is consumed correctly" {
  run cat "$SKILL"
  assert_output --partial "Mock that unit."
  assert_output --partial "pass only when the mock is consumed correctly"
  assert_output --partial "Change the consumer implementation to consume it."
  assert_output --partial "visible reason"
}

@test "when the mocked unit becomes the subject then it receives a tree and the process restarts" {
  run cat "$SKILL"
  assert_output --partial "Record the mocked unit's consumer-established behaviour in its own tree"
  assert_output --partial "Return to step 1"
  assert_output --partial "Keep the original consumer test."
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

@test "when TDD is complete then trees tests implementation and production consumption are complete" {
  run cat "$SKILL"
  assert_output --partial "Every affected tree path passes."
  assert_output --partial "Every mocked unit has its own tree and test file."
  assert_output --partial "Every test hierarchy mirrors its tree verbatim."
  assert_output --partial "Production consumes real units; mocks remain in tests."
}

@test "the narrow TDD skill does not explain architecture or other skills" {
  run grep -Ei 'hexagonal|skills/(change|sync|setup|workflow)|`(change|sync|setup|workflow)`' "$SKILL"
  assert_failure
}
