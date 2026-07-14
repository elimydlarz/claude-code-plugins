#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change/SKILL.md"

@test "change captures the outermost tree as a Journey for a broad arc or Component for one capability" {
  run cat "$SKILL"
  assert_output --partial "Journey tree"
  assert_output --partial "Component tree"
  assert_output --partial "consumer"
}

@test "change writes only the outermost tree up front and lets failing consumer tests reveal Integration and Unit tests" {
  run cat "$SKILL"
  assert_output --regexp "only that one|only the outermost tree"
  assert_output --partial "Integration"
  assert_output --partial "Unit"
  assert_output --partial "failing consumer test"
}

@test "change writes one tree per behavioural subject at its test kind" {
  run cat "$SKILL"
  assert_output --partial "subject"
  assert_output --partial "test kind"
  assert_output --partial "observable"
}

@test "change defines Component as a deep in-process whole-app capability test with external services doubled" {
  run cat "$SKILL"
  assert_output --partial "Component"
  assert_output --partial "deep in-process"
  assert_output --partial "external services replaced by test doubles"
}

@test "change teaches every test kind as consumer-driven" {
  run cat "$SKILL"
  assert_output --partial "consumer-driven"
  assert_output --partial "consumer test"
}

@test "change defines Journey Component Integration and Unit without the removed test kinds" {
  run cat "$SKILL"
  assert_output --partial "Journey: broad, production-like test of a curated user arc across capabilities"
  assert_output --partial "Component: deep in-process test of one capability through the whole app"
  assert_output --partial "Integration: when concerned integration of some (but not all) pieces"
  assert_output --partial "Unit: test of one public surface on one subject"
  refute_output --partial "System: deep"
  refute_output --partial "Adapter: test"
  refute_output --partial "Port contract: tests"
}

@test "change forbids designing Integration and Unit trees up front from speculation" {
  run cat "$SKILL"
  assert_output --regexp "YAGNI failure|speculation"
  assert_output --regexp "not designed ahead of time|not designed up front|hasn't asked"
}

@test "change enforces one tree, one test file" {
  run cat "$SKILL"
  [[ "$output" == *"One tree, one test file"* || "$output" == *"one tree reifies exactly one test file"* ]]
}

@test "change names trees for the highest-level subject with observable behaviour at their test kind" {
  run cat "$SKILL"
  assert_output --partial "highest-level subject"
  assert_output --partial "observable"
  assert_output --partial "test kind"
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

@test "change writes a shared behavioural suite for each port" {
  run cat "$SKILL"
  assert_output --partial "shared"
  assert_output --partial "behavioural suite"
}

@test "change requires both adapters to pass the shared behavioural suite" {
  run cat "$SKILL"
  [[ "$output" == *"both adapters"* || "$output" == *"both must pass"* ]]
}

@test "change gives every public surface on a pure library a Unit tree" {
  run cat "$SKILL"
  assert_output --partial "pure library"
  assert_output --partial "every public surface"
  assert_output --partial "Unit tree"
}

@test "change classifies domain use-case adapter and port implementation public surfaces as Unit tests" {
  run cat "$SKILL"
  assert_output --partial "domain object"
  assert_output --partial "use-case"
  assert_output --partial "adapter"
  assert_output --partial "port implementation"
  assert_output --partial "Unit"
}

@test "change captures app-level invariants at the highest test kind whose subject exposes the policy" {
  run cat "$SKILL"
  assert_output --partial "app-level"
  assert_output --partial "highest test kind"
  assert_output --partial "policy"
}

@test "change defines Integration from the highest-level subject and mocks everything except integrated subjects" {
  run cat "$SKILL"
  assert_output --partial "highest-level subject"
  assert_output --partial "mock everything except"
  assert_output --partial "subjects"
}
