#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/fix-architecture/SKILL.md"

@test "when an operator asks to fix architecture violations then the skill runs the architecture linter and partitions the reported violations into non-overlapping work for subagents" {
  run cat "$SKILL"
  assert_output --partial "Run the project's architecture command first"
  assert_output --partial "complete output"
  assert_output --partial "non-overlapping work"
  assert_output --partial "subagents"
}

@test "when an operator asks to fix architecture violations then subagents preserve observable behaviour while fixing violations without disabling rules, weakening boundaries, adding exemptions, or deleting behaviour" {
  run cat "$SKILL"
  assert_output --partial "Do not disable rules"
  assert_output --partial "weaken boundaries"
  assert_output --partial "add exemptions"
  assert_output --partial "preserve observable behavior"
  assert_output --partial "delete behavior"
}

@test "when an operator asks to fix architecture violations then affected normal tests pass before the skill reports completion" {
  run cat "$SKILL"
  assert_output --partial "affected normal tests"
  assert_output --partial "Do not report completion"
}

@test "when an operator asks to fix architecture violations then the coding agent reconciles their changes and reruns every architecture rule" {
  run cat "$SKILL"
  assert_output --partial "Reconcile"
  assert_output --partial "shared seams"
  assert_output --partial "rerun the complete architecture command"
}

@test "when an operator asks to fix architecture violations then repeated violations are repartitioned and fixed until architecture lint passes" {
  run cat "$SKILL"
  assert_output --partial "Repartition every remaining violation"
  assert_output --partial "until architecture lint passes"
  assert_output --partial "Do not report completion while any violation remains"
}

@test "if a violation conflicts with the operator's intended architecture then the skill resolves the architecture and mental-model decision with the operator before changing the enforced boundary" {
  run cat "$SKILL"
  assert_output --partial "operator's intended architecture"
  assert_output --partial "MENTAL_MODEL.md"
  assert_output --partial "resolve the decision with the operator"
  assert_output --partial "before changing the enforced boundary"
}
