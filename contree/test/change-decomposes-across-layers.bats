#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change/SKILL.md"

@test "change captures the outermost tree — a Journey tree for a new arc or a System tree for a capability under an existing journey" {
  run cat "$SKILL"
  [[ "$output" == *"Journey tree"* ]]
  [[ "$output" == *"System tree"* ]]
  [[ "$output" == *"consumer"* ]]
}

@test "change writes only the outermost tree up front; System and inner trees are added on failing-journey/functional-test pressure" {
  run cat "$SKILL"
  [[ "$output" == *"only that one"* || "$output" == *"only the outermost tree"* ]]
  [[ "$output" == *"failing journey/functional test"* ]]
}

@test "change writes one tree per behavioural unit at its layer" {
  run cat "$SKILL"
  [[ "$output" == *"behavioural unit"* ]]
  [[ "$output" == *"Domain"* ]]
  [[ "$output" == *"Use-case"* ]]
  [[ "$output" == *"Adapter"* ]]
  [[ "$output" == *"port contract"* ]]
}

@test "change names the Component layer between System and Adapter" {
  run cat "$SKILL"
  [[ "$output" == *"Component"* ]]
  [[ "$output" == *"*.component.test.*"* ]]
  [[ "$output" == *"edge"* ]]
}

@test "change teaches the 2x2: Use-case is to Component as Journey is to System" {
  run cat "$SKILL"
  [[ "$output" == *"Use-case is to Component as Journey is to System"* ]]
  [[ "$output" == *"behaviour-oriented"* ]]
  [[ "$output" == *"system-oriented"* ]]
}

@test "change forbids designing inner-layer trees up front from speculation" {
  run cat "$SKILL"
  [[ "$output" == *"YAGNI failure"* || "$output" == *"speculation"* ]]
  [[ "$output" == *"not designed ahead of time"* || "$output" == *"not designed up front"* || "$output" == *"hasn't asked"* ]]
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
