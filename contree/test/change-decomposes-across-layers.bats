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

@test "change teaches every layer as consumer-driven" {
  run cat "$SKILL"
  assert_output --partial "every layer is consumer-driven"
  assert_output --partial "higher-level tree and failing test create the demand for the next inner unit"
}

@test "change treats Use-case and Component as always-written exhaustive coverage, System and Journey as selective" {
  run cat "$SKILL"
  assert_output --partial "always written and exhaustive"
  assert_output --partial "Component and Use-case carry exhaustive"
  assert_output --partial "System and Journey validate the same surfaces with real everything, selectively"
}

@test "change forbids designing inner-layer trees up front from speculation" {
  run cat "$SKILL"
  assert_output --regexp "YAGNI failure|speculation"
  assert_output --regexp "not designed ahead of time|not designed up front|hasn't asked"
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

@test "change writes a System tree for pure libraries only when a cross-function invariant is observable, otherwise omits and documents it" {
  run cat "$SKILL"
  assert_output --partial "Pure libraries (no vertical slice)"
  assert_output --partial "no driving adapter, no use-case, and no driven port"
  assert_output --partial "ShortCode"
  assert_output --partial "If no cross-function invariant exists, omit System altogether and document the omission"
}

@test "change writes a Domain, Use-case, Driving-adapter, or Driven-adapter tree only for units with substantive behaviour beyond their contract" {
  run cat "$SKILL"
  assert_output --partial "Trivial value objects don't earn a tree"
  assert_output --partial "A use-case that just delegates to a single port doesn't earn a tree"
  assert_output --partial "Thin adapters don't earn a tree"
  assert_output --partial "adapter-specific behaviour beyond the port contract"
}

@test "change captures app-level invariants that span slices as a cross-cutting System tree named for the policy" {
  run cat "$SKILL"
  assert_output --partial "Cross-cutting System trees"
  assert_output --partial "auth enforcement, rate limiting, error envelope"
  assert_output --partial "write a System tree named for the policy"
}

@test "change wires the real driven adapter for System tests, never the in-memory twin, even when a Use-case in-memory twin exists" {
  run cat "$SKILL"
  assert_output --partial "System tests do NOT lean on the in-memory adapter"
  assert_output --partial "wire real driven adapters and exercise real infrastructure"
  assert_output --partial "dilute System tests into slow Use-case tests"
}
