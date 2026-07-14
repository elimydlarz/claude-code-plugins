#!/usr/bin/env bats

load test_helper

TEST_FEEDBACK="$PROJECT_ROOT/skills/setup-test-feedback/SKILL.md"
MUTATION_TESTING="$PROJECT_ROOT/skills/setup-mutation-testing/SKILL.md"

@test "when a project uses contree then Unit tests are colocated with their subjects (*.unit.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "*.unit.test.*"
  assert_output --partial "colocated"
}

@test "when a project uses contree and Integration tests are colocated with their highest-level subjects (*.integration.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "*.integration.test.*"
  assert_output --partial "colocated"
}

@test "when a project uses contree and Journey tests live under test/journey/ (*.journey.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "test/journey/"
  assert_output --partial "*.journey.test.*"
}

@test "when a project uses contree and Journey tests exercise a broad production-like user arc across capabilities, replacing external services with test doubles only when unavoidable" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "broad, production-like test of a curated user arc across capabilities"
  assert_output --partial "test doubles only if unavoidable"
}

@test "when a project uses contree and Component tests live under test/component/ (*.component.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "test/component/"
  assert_output --partial "*.component.test.*"
}

@test "when a project uses contree and Component tests exercise one capability deeply through the whole app in-process, replacing external services with test doubles" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "deep in-process test of one capability through the whole app"
  assert_output --partial "external services replaced by test doubles"
}

@test "when a project uses contree and Integration tests start from the highest-level subject and mock everything except the subjects whose real collaboration they verify" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "highest-level subject"
  assert_output --partial "mock everything except"
  assert_output --partial "subjects you are integrating"
}

@test "when a project uses contree and Unit tests exercise every public surface on one subject while mocking every dependency outside that subject" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "every public surface"
  assert_output --partial "native unit tests"
  assert_output --partial "every dependency outside the subject is mocked"
}

@test "when a project uses contree and every test kind produces tree-shaped output" {
  run cat "$TEST_FEEDBACK"
  [[ "$output" == *"tree-shaped"* || "$output" == *"tree output"* || "$output" == *"tree reporters"* ]]
}

@test "when a project uses contree and mutation testing validates Unit-test quality" {
  run cat "$MUTATION_TESTING"
  assert_output --partial "mutation testing"
  assert_output --partial "Unit tests"
}
