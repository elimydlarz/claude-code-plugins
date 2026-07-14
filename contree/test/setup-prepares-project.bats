#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "when an operator asks for comprehensive Contree setup then setup inspects the project and presents a dynamic setup workflow shaped by the steering that is missing" {
  run cat "$SKILL"
  assert_output --partial "dynamic setup workflow"
  assert_output --partial "setup-test-feedback"
  assert_output --partial "setup-linter"
  assert_output --partial "setup-architecture-linter"
  assert_output --partial "setup-mental-model"
  assert_output --partial "setup-test-trees"
  assert_output --partial "bootstrap-test-trees"
  assert_output --partial "setup-mutation-testing"
}

@test "when an operator asks for comprehensive Contree setup then each completed setup phase expands project-local hooks so later coding agents receive progressively richer steering while they work" {
  run cat "$SKILL"
  assert_output --partial "Contree progressively expanding into the project"
  assert_output --partial "prove its project-local hooks before continuing"
  assert_output --partial "receives all steering installed by the earlier phases"
  assert_output --partial "Preserve and merge earlier hooks"
}

@test "when an operator asks for comprehensive Contree setup then setup engages the operator only when project evidence cannot settle a consequential framework, architecture, behavioural-scope, or mutation-threshold decision" {
  run cat "$SKILL"
  assert_output --partial "framework"
  assert_output --partial "architecture"
  assert_output --partial "behavioural scope"
  assert_output --partial "mutation threshold"
  assert_output --partial "operator"
}

@test "when an operator asks for comprehensive Contree setup then setup orchestrates setup-test-feedback, setup-linter, setup-architecture-linter, bootstrap-test-trees, and setup-mutation-testing while bootstrap composes setup-mental-model and setup-test-trees" {
  run cat "$SKILL"
  assert_output --partial "setup-test-feedback"
  assert_output --partial "setup-linter"
  assert_output --partial "setup-architecture-linter"
  assert_output --partial "bootstrap-test-trees"
  assert_output --partial "setup-mutation-testing"
  assert_output --partial "setup-mental-model"
  assert_output --partial "setup-test-trees"
}

@test "when an operator asks for comprehensive Contree setup then setup invokes fix-architecture when architecture feedback reports violations" {
  run cat "$SKILL"
  assert_output --partial "fix-architecture"
  assert_output --partial "architecture command reports violations"
}

@test "when an operator asks for comprehensive Contree setup then setup orders dependent phases so test feedback precedes bootstrap, mental-model setup precedes test-tree setup, conventional lint precedes architecture lint, architecture repair precedes bootstrap, and bootstrap precedes mutation testing" {
  run cat "$SKILL"
  assert_output --partial "setup-test-feedback` before `bootstrap-test-trees"
  assert_output --partial "setup-mental-model` runs before `setup-test-trees"
  assert_output --partial "setup-linter` before `setup-architecture-linter"
  assert_output --partial "finish that repair before bootstrap"
  assert_output --partial "before mutation setup begins"
}

@test "when an operator asks for comprehensive Contree setup then setup uses subagents for independent setup work and reconciles their results" {
  run cat "$SKILL"
  assert_output --partial "subagents"
  assert_output --partial "non-overlapping"
  assert_output --partial "reconcile"
}

@test "when an operator asks for comprehensive Contree setup then setup keeps focused-skill orchestration in the coordinator instead of delegating an entire focused skill to an unattended background agent" {
  run cat "$SKILL"
  assert_output --partial "Do not delegate an entire focused skill"
  assert_output --partial "unattended background agent"
  assert_output --partial "wait for every selected phase"
  assert_output --partial "no subagent is still running"
}

@test "when an operator asks for comprehensive Contree setup then setup waits for every selected phase and its subagents to finish before starting a dependent phase or reporting completion" {
  run cat "$SKILL"
  assert_output --partial "wait for every selected phase"
  assert_output --partial "no subagent is still running"
  assert_output --partial "before starting dependent work"
}

@test "when an operator asks for comprehensive Contree setup then setup proves each phase from its required commands and retained artifacts rather than accepting a subagent summary as proof" {
  run cat "$SKILL"
  assert_output --partial "Never accept a subagent summary as proof"
  assert_output --partial "consumer-driven EARS tree"
  assert_output --partial "exactly one retained test file"
  assert_output --partial "before mutation setup begins"
}

@test "when an operator asks for comprehensive Contree setup then setup proves bootstrap retained consumer-driven EARS trees with exactly one test file per tree before mutation setup begins" {
  run cat "$SKILL"
  assert_output --partial "consumer-driven EARS tree"
  assert_output --partial "exactly one retained test file"
  assert_output --partial "before mutation setup begins"
}

@test "when an operator asks for comprehensive Contree setup then setup runs every configured feedback command, proves save hooks through file edits and Stop hooks through actual Stop turns, and fixes failures before reporting the project prepared" {
  run cat "$SKILL"
  assert_output --partial "test"
  assert_output --partial "lint"
  assert_output --partial "architecture"
  assert_output --partial "mutation"
  assert_output --partial "fix"
  assert_output --partial "verify"
  assert_output --partial 'native `test-changed` command and the actual synchronous project save hooks'
  assert_output --partial "Verify each save hook"
  assert_output --partial "actual file edit"
  assert_output --partial "actual Stop turn"
}

@test "when an operator asks for comprehensive Contree setup then setup reports the installed commands, automatic hooks, test-tree coverage, and mutation result to the operator" {
  run cat "$SKILL"
  assert_output --partial "installed commands"
  assert_output --partial "automatic hooks"
  assert_output --partial "mental-model and test-tree steering"
  assert_output --partial "test-tree coverage"
  assert_output --partial "mutation result"
}

@test "if a specialised setup skill cannot establish its feedback loop then setup fails without claiming the project is prepared" {
  run cat "$SKILL"
  assert_output --partial "fail visibly"
  assert_output --partial "Do not claim"
}
