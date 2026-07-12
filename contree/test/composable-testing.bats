#!/usr/bin/env bats

load test_helper

TEST_FEEDBACK="$PROJECT_ROOT/skills/setup-test-feedback/SKILL.md"
MUTATION_TESTING="$PROJECT_ROOT/skills/setup-mutation-testing/SKILL.md"

@test "setup colocates Domain tests with source (*.domain.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "*.domain.test.*"
  assert_output --partial "colocated"
}

@test "setup colocates Use-case tests with the use-case (*.use-case.test.*)" {
  run cat "$TEST_FEEDBACK"
  [[ "$output" == *"*.use-case.test.*"* ]]
}

@test "setup colocates Adapter tests with the adapter (*.adapter.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "*.adapter.test.*"
  assert_output --partial "colocated"
  assert_output --partial "driving"
  assert_output --partial "driven"
}

@test "setup places System tests under test/system/ (*.system.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "test/system/"
  assert_output --partial "*.system.test.*"
}

@test "setup places Journey tests under test/journey/ (*.journey.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "test/journey/"
  assert_output --partial "*.journey.test.*"
}

@test "setup wires Journey tests with real adapters across the multi-capability arc at max realism" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "multi-capability arc at max realism"
  assert_output --partial "real everything"
}

@test "setup places Component tests under test/component/ (*.component.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "test/component/"
  assert_output --partial "*.component.test.*"
}

@test "setup wires Component tests with real adapters and externals doubled at the edge" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "real driving and driven adapters"
  assert_output --partial "one capability"
  assert_output --partial "in-memory database"
  assert_output --partial "stubbed outbound HTTP"
}

@test "setup places exhaustive single-capability breadth at Component and Use-case layers" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "exhaustive single-capability"
  assert_output --partial "Use-case and Component"
}

@test "setup wires System tests with real driven adapters at the highest tolerable realism by default" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "real driven adapters"
  assert_output --regexp "highest tolerable realism|max realism|max-realism"
}

@test "setup produces tree-shaped output at every layer" {
  run cat "$TEST_FEEDBACK"
  [[ "$output" == *"tree-shaped"* || "$output" == *"tree output"* || "$output" == *"tree reporters"* ]]
}

@test "setup validates quality with mutation testing at Domain and Use-case layers" {
  run cat "$MUTATION_TESTING"
  assert_output --partial "mutation testing"
  assert_output --partial "Domain"
  assert_output --partial "Use-case"
}
