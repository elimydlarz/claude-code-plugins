#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup-test-trees/SKILL.md"

@test "when an operator asks to set up test trees for an existing project then the skill explains the behavioural evidence it will gather and agrees complete non-overlapping scope with the operator" {
  run cat "$SKILL"
  assert_output --partial "Explain the behavioural evidence"
  assert_output --partial "Agree complete non-overlapping scope with the operator"
}

@test "when an operator asks to set up test trees for an existing project then discovery subagents inspect every area for observable behaviour, existing tests, public seams, errors, side effects, and contradictions" {
  run cat "$SKILL"
  assert_output --partial "discovery subagents"
  assert_output --partial "observable behaviour, existing tests, public seams, errors, side effects, and contradictions"
  assert_output --partial "every agreed area exactly once"
}

@test "when an operator asks to set up test trees for an existing project then the coding agent reconciles the evidence with the operator through change into layered EARS trees with honest coverage" {
  run cat "$SKILL"
  assert_output --partial "Reconcile the evidence"
  assert_output --partial 'through `change`'
  assert_output --partial "layered EARS trees"
  assert_output --partial "honest coverage"
}

@test "when an operator asks to set up test trees for an existing project then every discovered behaviour is expressed at its consumer-visible seam without inventing unsupported behaviour" {
  run cat "$SKILL"
  assert_output --partial "consumer-visible seam"
  assert_output --partial "Do not invent unsupported behaviour"
  assert_output --partial "Do not implement tests"
}

@test "when an operator asks to set up test trees for an existing project then project SessionStart hooks load TEST_TREES.md and the tree-writing rules before coding agents work" {
  run cat "$SKILL"
  assert_output --partial '.contree/hooks/test-trees-session-start.sh'
  assert_output --partial 'cat TEST_TREES.md'
  assert_output --partial 'SessionStart'
  assert_output --partial '.claude/settings.json'
  assert_output --partial '.codex/hooks.json'
  assert_output --partial "tree-writing rules"
}

@test "when an operator asks to set up test trees for an existing project then project Stop hooks ask the coding agent to reconcile drift between trees, tests, and implementation before it finishes" {
  run cat "$SKILL"
  assert_output --partial '.contree/hooks/test-trees-on-stop.sh'
  assert_output --partial 'stop_hook_active'
  assert_output --partial "reconcile drift between trees, tests, and implementation"
  assert_output --partial "exit 2"
  assert_output --partial "before it finishes"
}

@test "when an operator asks to set up test trees for an existing project then the skill proves both hooks through actual coding-agent turns before reporting completion" {
  run cat "$SKILL"
  assert_output --partial "actual coding-agent SessionStart turn"
  assert_output --partial "actual coding-agent Stop turn"
  assert_output --partial "Presence on disk is not proof"
  assert_output --partial "Do not report completion"
}

@test "when an operator asks to set up test trees for a new project then the skill creates an empty test-tree home without inventing behaviour" {
  run cat "$SKILL"
  assert_output --partial 'empty `TEST_TREES.md`'
  assert_output --partial "Do not invent behaviour"
  assert_output --partial "Do not create test files"
}

@test "when an operator asks to set up test trees for a new project then it installs and proves the same project-local steering hooks" {
  run cat "$SKILL"
  assert_output --partial "Install and prove the same project-local SessionStart and Stop hooks"
  assert_output --partial "merge"
  assert_output --partial "without replacing existing settings or hooks"
}
