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

@test "change pairs each outbound port with an in-memory adapter used by Use-case and System tests" {
  run cat "$CHANGE"
  [[ "$output" == *"in-memory adapter"* ]]
  [[ "$output" == *"Use-case"* ]]
  [[ "$output" == *"System"* ]]
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
