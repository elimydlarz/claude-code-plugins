#!/usr/bin/env bats

load test_helper

SETUP="$PROJECT_ROOT/skills/setup/SKILL.md"
CHANGE="$PROJECT_ROOT/skills/change/SKILL.md"

@test "setup colocates Domain tests with source (*.domain.test.*)" {
  run cat "$SETUP"
  assert_output --partial "*.domain.test.*"
  assert_output --partial "colocated"
}

@test "setup colocates Use-case tests with the use-case (*.use-case.test.*)" {
  run cat "$SETUP"
  [[ "$output" == *"*.use-case.test.*"* ]]
}

@test "setup colocates Adapter tests with the adapter (*.adapter.test.*)" {
  run cat "$SETUP"
  [[ "$output" == *"*.adapter.test.*"* ]]
}

@test "setup places System tests under test/system/ (*.system.test.*)" {
  run cat "$SETUP"
  assert_output --partial "test/system/"
  assert_output --partial "*.system.test.*"
}

@test "setup places Journey tests under test/journey/ (*.journey.test.*)" {
  run cat "$SETUP"
  assert_output --partial "test/journey/"
  assert_output --partial "*.journey.test.*"
}

@test "setup places Component tests under test/component/ (*.component.test.*)" {
  run cat "$SETUP"
  assert_output --partial "test/component/"
  assert_output --partial "*.component.test.*"
}

@test "setup wires Component tests with real adapters and externals doubled at the edge" {
  run cat "$SETUP"
  assert_output --partial "in-memory database"
  assert_output --partial "stubbed outbound HTTP"
}

@test "change pairs each outbound port with an in-memory adapter used by Use-case tests" {
  run cat "$CHANGE"
  assert_output --partial "in-memory adapter"
  assert_output --partial "Use-case tests"
}

@test "change wires System tests with real driven adapters at the highest tolerable realism by default" {
  run cat "$CHANGE"
  assert_output --partial "real driven adapters"
  assert_output --regexp "highest tolerable realism|max realism|max-realism"
}

@test "change leans on the journey when breadth at max realism is unaffordable" {
  run cat "$CHANGE"
  assert_output --regexp "unaffordable|unafford"
  assert_output --partial "lean on the journey"
}

@test "change pairs each outbound port with a shared contract suite" {
  run cat "$CHANGE"
  assert_output --partial "shared"
  assert_output --partial "contract"
}

@test "setup produces tree-shaped output at every layer" {
  run cat "$SETUP"
  [[ "$output" == *"tree-shaped"* || "$output" == *"tree output"* || "$output" == *"tree reporters"* ]]
}

@test "setup validates quality with mutation testing at Domain and Use-case layers" {
  run cat "$SETUP"
  assert_output --partial "mutation testing"
  assert_output --partial "Domain"
  assert_output --partial "Use-case"
}
