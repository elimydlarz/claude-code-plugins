#!/usr/bin/env bats

load test_helper

TEST_FEEDBACK="$PROJECT_ROOT/skills/setup-test-feedback/SKILL.md"
MUTATION_TESTING="$PROJECT_ROOT/skills/setup-mutation-testing/SKILL.md"

@test "when a project uses contree then Domain tests are colocated with their subjects (*.domain.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "*.domain.test.*"
}

@test "when a project uses contree and Use-case tests are colocated with their subjects (*.use-case.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "*.use-case.test.*"
}

@test "when a project uses contree and Adapter tests are colocated with their adapters (*.adapter.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "*.adapter.test.*"
}

@test "when a project uses contree and Port contract tests are colocated with their ports (*.port-contract.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "*.port-contract.test.*"
}

@test "when a project uses contree and Component tests live under test/component/ (*.component.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "test/component/"
  assert_output --partial "*.component.test.*"
}

@test "when a project uses contree and System tests live under test/system/ (*.system.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "test/system/"
  assert_output --partial "*.system.test.*"
}

@test "when a project uses contree and Journey tests live under test/journey/ (*.journey.test.*)" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "test/journey/"
  assert_output --partial "*.journey.test.*"
}

@test "when a project uses contree and Journey tests exercise a broad production-like user arc across capabilities" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "broad, production-like test of a curated user arc across capabilities"
}

@test "when a project uses contree and System tests exercise one capability deeply through the whole production-like app" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "deep, production-like test of one capability through the whole app"
}

@test "when a project uses contree and Component tests exercise one capability deeply through the whole app in-process, replacing external services with test doubles" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "deep in-process test of one capability through the whole app"
  assert_output --partial "external services replaced by test doubles"
}

@test "when a project uses contree and Adapter tests exercise one concrete boundary implementation against the real boundary it adapts" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "one concrete boundary implementation against the real boundary it adapts"
}

@test "when a project uses contree and Port contract tests exercise every implementation of an application interface through one shared contract" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "every implementation of an application interface through one shared contract"
}

@test "when a project uses contree and Unit tests exercise every public surface of Domain and Use-case subjects while mocking every dependency outside that subject" {
  run cat "$TEST_FEEDBACK"
  assert_output --partial "every public surface of Domain and Use-case subjects"
  assert_output --partial "every dependency outside the subject mocked"
}

@test "when a project uses contree and every test kind produces tree-shaped output" {
  run cat "$TEST_FEEDBACK"
  [[ "$output" == *"tree-shaped"* || "$output" == *"tree output"* || "$output" == *"tree reporters"* ]]
}

@test "when a project uses contree and mutation testing validates Domain and Use-case test quality" {
  run cat "$MUTATION_TESTING"
  assert_output --partial "mutation testing"
  assert_output --partial "Domain and Use-case tests"
}
