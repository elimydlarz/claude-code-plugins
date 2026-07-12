#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "when an operator asks for comprehensive Contree setup then setup presents and runs a dynamic workflow for every missing steering loop" {
  run cat "$SKILL"
  assert_output --partial "dynamic setup workflow"
  assert_output --partial "setup-test-feedback"
  assert_output --partial "setup-linter"
  assert_output --partial "setup-architecture-linter"
  assert_output --partial "bootstrap-test-trees"
  assert_output --partial "setup-mutation-testing"
}

@test "when an operator asks for comprehensive Contree setup then setup engages the operator at consequential setup decisions" {
  run cat "$SKILL"
  assert_output --partial "framework"
  assert_output --partial "architecture"
  assert_output --partial "behavioural scope"
  assert_output --partial "mutation threshold"
  assert_output --partial "operator"
}

@test "when an operator asks for comprehensive Contree setup then setup uses subagents for independent setup work and reconciles their results" {
  run cat "$SKILL"
  assert_output --partial "subagents"
  assert_output --partial "non-overlapping"
  assert_output --partial "reconcile"
}

@test "when comprehensive setup orchestrates focused skills then the coordinator does not abandon a focused skill in a background agent" {
  run cat "$SKILL"
  assert_output --partial "Do not delegate an entire focused skill"
  assert_output --partial "unattended background agent"
  assert_output --partial "wait for every selected phase"
  assert_output --partial "no subagent is still running"
}

@test "when a focused setup phase reports completion then setup proves its retained artifacts before continuing" {
  run cat "$SKILL"
  assert_output --partial "Never accept a subagent summary as proof"
  assert_output --partial "layered EARS tree"
  assert_output --partial "exactly one retained test file"
  assert_output --partial "before mutation setup begins"
}

@test "when an operator asks for comprehensive Contree setup then setup verifies and fixes every configured feedback command" {
  run cat "$SKILL"
  assert_output --partial "test"
  assert_output --partial "lint"
  assert_output --partial "architecture"
  assert_output --partial "mutation"
  assert_output --partial "fix"
  assert_output --partial "verify"
}

@test "when comprehensive Contree setup completes then setup reports the steering installed for the operator" {
  run cat "$SKILL"
  assert_output --partial "installed commands"
  assert_output --partial "automatic hooks"
  assert_output --partial "test-tree coverage"
  assert_output --partial "mutation result"
}

@test "if a specialised setup skill cannot establish its feedback loop then setup fails without claiming the project is prepared" {
  run cat "$SKILL"
  assert_output --partial "fail visibly"
  assert_output --partial "Do not claim"
}
