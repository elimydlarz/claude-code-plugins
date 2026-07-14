#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change/SKILL.md"

@test "when a behaviour change is planned then the outermost tree is captured as a Journey for a new user arc or System for a capability under an existing journey" {
  run cat "$SKILL"
  assert_output --partial "Journey tree"
  assert_output --partial "System tree"
  assert_output --partial "consumer"
}

@test "when a behaviour change is planned then only the outermost tree is written up front and failing consumer tests reveal inner-layer trees" {
  run cat "$SKILL"
  assert_output --regexp "only that one|only the outermost tree"
  assert_output --partial "inner-layer trees"
  assert_output --partial "failing consumer test"
}

@test "when a behaviour change is planned then trees are named for the subject with observable behaviour at their natural layer" {
  run cat "$SKILL"
  assert_output --partial "subject"
  assert_output --partial "natural layer"
  assert_output --partial "observable"
}

@test "change defines Component as a deep in-process whole-app capability test with external services doubled" {
  run cat "$SKILL"
  assert_output --partial "Component"
  assert_output --partial "deep in-process"
  assert_output --partial "external services replaced by test doubles"
}

@test "when choosing a test layer then every layer is consumer-driven" {
  run cat "$SKILL"
  assert_output --partial "consumer-driven"
  assert_output --partial "consumer test"
}

@test "when choosing a test layer then Journey, System, Component, Adapter, Domain, Use-case, and Port use their distinct native test kinds" {
  run cat "$SKILL"
  assert_output --partial "Journey: broad, production-like test of a curated user arc across capabilities"
  assert_output --partial "System: deep, production-like test of one capability through the whole app"
  assert_output --partial "Component: deep in-process test of one capability through the whole app"
  assert_output --partial "Adapter: test of one concrete boundary implementation"
  assert_output --partial "Port contract: tests for an application interface"
  assert_output --partial "Domain and Use-case trees describe Unit tests"
}

@test "when an inner-layer tree is added then it is never designed up front from speculation" {
  run cat "$SKILL"
  assert_output --regexp "YAGNI failure|speculation"
  assert_output --regexp "not designed ahead of time|not designed up front|hasn't asked"
}

@test "change enforces one tree, one test file" {
  run cat "$SKILL"
  [[ "$output" == *"One tree, one test file"* || "$output" == *"one tree reifies exactly one test file"* ]]
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

@test "when a side effect is identified then a shared Port contract suite is written" {
  run cat "$SKILL"
  assert_output --partial "shared"
  assert_output --partial "shared contract suite"
}

@test "when a side effect is identified then both adapters pass the shared Port contract suite" {
  run cat "$SKILL"
  [[ "$output" == *"both adapters"* || "$output" == *"both must pass"* ]]
}

@test "when a potential inner subject has only trivial delegation or value behaviour then it does not receive a speculative tree" {
  run cat "$SKILL"
  assert_output --partial "Trivial value objects"
  assert_output --partial "single-port delegation"
  assert_output --partial "thin adapters"
  assert_output --partial "do not earn trees"
}

@test "when an app-level invariant applies across slices rather than to one then it is captured in a System tree named for the policy" {
  run cat "$SKILL"
  assert_output --partial "app-level"
  assert_output --partial "Cross-cutting System trees"
  assert_output --partial "policy"
}
