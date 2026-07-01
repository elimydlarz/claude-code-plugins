#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change/SKILL.md"

@test "change captures the outermost tree — a Journey tree for a new arc or a System tree for a capability under an existing journey" {
  run cat "$SKILL"
  assert_output --partial "Journey tree"
  assert_output --partial "System tree"
  assert_output --partial "consumer"
}

@test "change writes only the outermost tree up front; System and inner trees are added on failing-journey/functional-test pressure" {
  run cat "$SKILL"
  assert_output --regexp "only that one|only the outermost tree"
  assert_output --partial "failing journey/functional test"
}

@test "change writes one tree per behavioural unit at its layer" {
  run cat "$SKILL"
  assert_output --partial "behavioural unit"
  assert_output --partial "Domain"
  assert_output --partial "Use-case"
  assert_output --partial "Adapter"
  assert_output --partial "port contract"
}

@test "change names the Component layer between System and Adapter" {
  run cat "$SKILL"
  assert_output --partial "Component"
  assert_output --partial "*.component.test.*"
  assert_output --partial "edge"
}

@test "change teaches the 2x2: Use-case is to Component as Journey is to System" {
  run cat "$SKILL"
  assert_output --partial "Use-case is to Component as Journey is to System"
  assert_output --partial "behaviour-oriented"
  assert_output --partial "system-oriented"
}

@test "change forbids designing inner-layer trees up front from speculation" {
  run cat "$SKILL"
  assert_output --regexp "YAGNI failure|speculation"
  assert_output --regexp "not designed ahead of time NOPE|not designed up front NOPE|hasn't asked NOPE"
}

@test "change enforces one tree, one test file" {
  run cat "$SKILL"
  [[ "$output" == *"One tree, one test file"* || "$output" == *"one tree reifies exactly one test file"* ]]
}

@test "change names trees for the subject with observable behaviour at their layer" {
  run cat "$SKILL"
  assert_output --partial "subject"
  assert_output --partial "observable"
}

@test "change turns side effects into outbound ports named for capability, not technology" {
  run cat "$SKILL"
  assert_output --partial "outbound port"
  assert_output --partial "capability"
  assert_output --regexp "not technology|not for technology"
}

@test "change ships each port in two flavours: in-memory and real adapters" {
  run cat "$SKILL"
  assert_output --partial "in-memory"
  assert_output --partial "real"
  assert_output --partial "adapter"
}

@test "change writes a shared contract suite for each port" {
  run cat "$SKILL"
  assert_output --partial "shared"
  assert_output --partial "contract"
}

@test "change requires both adapters to pass the shared contract suite" {
  run cat "$SKILL"
  [[ "$output" == *"both adapters"* || "$output" == *"both must pass"* ]]
}
