#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/bootstrap-test-trees/SKILL.md"

@test "when an operator asks to bootstrap test trees for an existing project then the skill explains the evidence it will gather and agrees the behavioural scope with the operator" {
  run cat "$SKILL"
  assert_output --partial "Explain the evidence"
  assert_output --partial "agree the behavioural scope with the operator"
}

@test "when an operator asks to bootstrap test trees for an existing project then subagents inspect non-overlapping areas of the project for observable behaviour, tests, architecture, and mental-model concepts" {
  run cat "$SKILL"
  assert_output --partial "non-overlapping areas"
  assert_output --partial "observable behaviour, existing tests, architecture, and mental-model concepts"
}

@test "when an operator asks to bootstrap test trees for an existing project then the coding agent reconciles their evidence into one coherent MENTAL_MODEL.md and TEST_TREES.md with the operator" {
  run cat "$SKILL"
  assert_output --partial "Reconcile"
  assert_output --partial 'one coherent `MENTAL_MODEL.md` and `TEST_TREES.md`'
  assert_output --partial "with the operator"
}

@test "when an operator asks to bootstrap test trees for an existing project then every discovered behaviour is expressed at its consumer-visible seam without inventing unsupported behaviour" {
  run cat "$SKILL"
  assert_output --partial "consumer-visible seam"
  assert_output --partial "Do not invent unsupported behaviour"
}

@test "when an operator asks to bootstrap test trees for an existing project then a second wave of subagents implements non-overlapping test trees as tests whose hierarchy mirrors each tree verbatim" {
  run cat "$SKILL"
  assert_output --partial "second wave of subagents"
  assert_output --partial "non-overlapping trees"
  assert_output --partial "hierarchy mirrors its tree verbatim"
}

@test "when an operator asks to bootstrap test trees for an existing project then the coding agent reconciles the test implementations and runs the normal and functional test commands" {
  run cat "$SKILL"
  assert_output --partial "Reconcile the test implementations"
  assert_output --partial "normal and functional test commands"
}

@test "when an operator asks to bootstrap test trees for a new project then the skill creates the seven-section mental-model home and an empty test-tree home" {
  run cat "$SKILL"
  assert_output --partial 'seven-section `MENTAL_MODEL.md`'
  assert_output --partial 'empty `TEST_TREES.md`'
}

@test "when an operator asks to bootstrap test trees for a new project then it leaves behaviour trees and tests to be pulled into existence by the first requested capability" {
  run cat "$SKILL"
  assert_output --partial "Do not write behaviour trees or tests"
  assert_output --partial "first requested capability"
}

@test "if bootstrapped tests expose behaviour that disagrees with the operator's intended contract then the disagreement is left visible and routed through change or tdd rather than weakened in the trees or tests" {
  run cat "$SKILL"
  assert_output --partial "Leave the disagreement visible"
  assert_output --partial 'route it through `change` or `tdd`'
  assert_output --partial "Do not weaken the trees or tests"
}
