#!/usr/bin/env bats

load test_helper

SETUP="$PROJECT_ROOT/skills/setup/SKILL.md"
CHANGE="$PROJECT_ROOT/skills/change/SKILL.md"

@test "setup colocates Domain tests with source (*.domain.test.*)" {
  run cat "$SETUP"
  [[ "$output" == *"*.domain.test.*"* ]]
  [[ "$output" == *"colocated"* ]]
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
  [[ "$output" == *"test/system/"* ]]
  [[ "$output" == *"*.system.test.*"* ]]
}

@test "setup places Journey tests under test/journey/ (*.journey.test.*)" {
  run cat "$SETUP"
  [[ "$output" == *"test/journey/"* ]]
  [[ "$output" == *"*.journey.test.*"* ]]
}

@test "setup places Component tests under test/component/ (*.component.test.*)" {
  run cat "$SETUP"
  [[ "$output" == *"test/component/"* ]]
  [[ "$output" == *"*.component.test.*"* ]]
}

@test "setup wires Component tests with real adapters and externals doubled at the edge" {
  run cat "$SETUP"
  [[ "$output" == *"in-memory database"* ]]
  [[ "$output" == *"stubbed outbound HTTP"* ]]
}

@test "change pairs each outbound port with an in-memory adapter used by Use-case tests" {
  run cat "$CHANGE"
  [[ "$output" == *"in-memory adapter"* ]]
  [[ "$output" == *"Use-case tests"* ]]
}

@test "change wires System tests with real driven adapters at the highest tolerable realism by default" {
  run cat "$CHANGE"
  [[ "$output" == *"real driven adapters"* ]]
  [[ "$output" == *"highest tolerable realism"* || "$output" == *"max realism"* || "$output" == *"max-realism"* ]]
}

@test "change leans on the journey when breadth at max realism is unaffordable" {
  run cat "$CHANGE"
  [[ "$output" == *"unaffordable"* || "$output" == *"unafford"* ]]
  [[ "$output" == *"lean on the journey"* ]]
}

@test "change pairs each outbound port with a shared contract suite" {
  run cat "$CHANGE"
  [[ "$output" == *"shared"* ]]
  [[ "$output" == *"contract"* ]]
}

@test "setup produces tree-shaped output at every layer" {
  run cat "$SETUP"
  [[ "$output" == *"tree-shaped"* || "$output" == *"tree output"* || "$output" == *"tree reporters"* ]]
}

@test "setup validates quality with mutation testing at Domain and Use-case layers" {
  run cat "$SETUP"
  [[ "$output" == *"mutation testing"* ]]
  [[ "$output" == *"Domain"* ]]
  [[ "$output" == *"Use-case"* ]]
}
