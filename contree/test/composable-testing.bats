#!/usr/bin/env bats

load test_helper

TEST_FEEDBACK="$PROJECT_ROOT/skills/setup-test-feedback/SKILL.md"
MUTATION_TESTING="$PROJECT_ROOT/skills/setup-mutation-testing/SKILL.md"

@test "setup colocates Unit tests with their subjects (*.unit.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "*.unit.test.*"
  assert_output --partial "colocated"
}

@test "setup colocates Integration tests with their highest-level subjects (*.integration.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "*.integration.test.*"
  assert_output --partial "colocated"
}

@test "setup places Journey tests under test/journey/ (*.journey.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "test/journey/"
  assert_output --partial "*.journey.test.*"
}

@test "setup defines Journey tests as broad production-like arcs with external services doubled only if unavoidable" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "broad, production-like test of a curated user arc across capabilities"
  assert_output --partial "test doubles only if unavoidable"
}

@test "setup places Component tests under test/component/ (*.component.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "test/component/"
  assert_output --partial "*.component.test.*"
}

@test "setup defines Component tests as deep in-process whole-app capability tests with external services doubled" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "deep in-process test of one capability through the whole app"
  assert_output --partial "external services replaced by test doubles"
}

@test "setup defines Integration tests from the highest-level subject with only integrated subjects real" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "highest-level subject"
  assert_output --partial "mock everything except"
  assert_output --partial "subjects you are integrating"
}

@test "setup gives every public surface native Unit tests with dependencies mocked" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "every public surface"
  assert_output --partial "native unit tests"
  assert_output --partial "every dependency outside the subject is mocked"
}

@test "setup produces tree-shaped output for every test kind" {
  run cat "$TEST_FEEDBACK"
  [[ "$output" == *"tree-shaped"* || "$output" == *"tree output"* || "$output" == *"tree reporters"* ]]
}

@test "setup validates Unit-test quality with mutation testing" {
  run cat "$MUTATION_TESTING"
  assert_output --partial "mutation testing"
  assert_output --partial "Unit tests"
}
