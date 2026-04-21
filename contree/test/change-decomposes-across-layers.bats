#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change/SKILL.md"

@test "change captures the slice as a System tree named for the consumer capability" {
  run cat "$SKILL"
  [[ "$output" == *"System tree"* ]]
  [[ "$output" == *"consumer"* ]]
}

@test "change writes one tree per behavioural unit at its layer" {
  run cat "$SKILL"
  [[ "$output" == *"behavioural unit"* ]]
  [[ "$output" == *"Domain"* ]]
  [[ "$output" == *"Use-case"* ]]
  [[ "$output" == *"Adapter"* ]]
  [[ "$output" == *"port contract"* ]]
}

@test "change enforces one tree, one test file" {
  run cat "$SKILL"
  [[ "$output" == *"One tree, one test file"* || "$output" == *"one tree reifies exactly one test file"* ]]
}

@test "change names trees for the subject with observable behaviour at their layer" {
  run cat "$SKILL"
  [[ "$output" == *"subject"* ]]
  [[ "$output" == *"observable"* ]]
}

@test "change turns side effects into outbound ports named for capability, not technology" {
  run cat "$SKILL"
  [[ "$output" == *"outbound port"* ]]
  [[ "$output" == *"capability"* ]]
  [[ "$output" == *"not technology"* || "$output" == *"not for technology"* ]]
}

@test "change ships each port in two flavours: in-memory and real adapters" {
  run cat "$SKILL"
  [[ "$output" == *"in-memory"* ]]
  [[ "$output" == *"real"* ]]
  [[ "$output" == *"adapter"* ]]
}

@test "change writes a shared contract suite for each port" {
  run cat "$SKILL"
  [[ "$output" == *"shared"* ]]
  [[ "$output" == *"contract"* ]]
}

@test "change requires both adapters to pass the shared contract suite" {
  run cat "$SKILL"
  [[ "$output" == *"both adapters"* || "$output" == *"both must pass"* ]]
}
