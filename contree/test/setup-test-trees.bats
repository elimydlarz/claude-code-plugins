#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup-test-trees/SKILL.md"

@test "when the skill classifies a project then consumer-visible behaviour makes it existing while its absence makes it new" {
  run cat "$SKILL"
  assert_output --partial "An existing project already exposes behaviour to a consumer"
  assert_output --partial "A new project has no consumer-visible behaviour"
}

@test "when an operator asks to set up test trees for an existing project then the skill explains the behavioural evidence it will gather and agrees complete non-overlapping scope with the operator" {
  run cat "$SKILL"
  assert_output --partial "Explain the behavioural evidence"
  assert_output --partial "Agree complete non-overlapping scope with the operator"
}

@test "when an operator asks to set up test trees for an existing project and discovery subagents inspect every area for observable behaviour, existing tests, public seams, errors, side effects, and contradictions" {
  run cat "$SKILL"
  assert_output --partial "discovery subagents"
  assert_output --partial "observable behaviour, existing tests, public seams, errors, side effects, and contradictions"
  assert_output --partial "every agreed area exactly once"
}

@test "when an operator asks to set up test trees for an existing project and the coding agent reconciles the evidence with the operator through change into consumer-driven EARS trees with honest coverage" {
  run cat "$SKILL"
  assert_output --partial "Reconcile the evidence"
  assert_output --partial 'through `change`'
  assert_output --partial "consumer-driven EARS trees"
  assert_output --partial "honest coverage"
}

@test "when an operator asks to set up test trees for an existing project and every discovered behaviour is expressed at its consumer-visible seam without inventing unsupported behaviour" {
  run cat "$SKILL"
  assert_output --partial "consumer-visible seam"
  assert_output --partial "Do not invent unsupported behaviour"
}

@test "when an operator asks to set up test trees for an existing project and operator agreement on the trees is required before steering is installed without creating tests or production behaviour" {
  run cat "$SKILL"
  assert_output --partial "obtain agreement before installing steering"
  assert_output --partial "Do not implement tests"
  assert_output --partial "change production behaviour"
}

@test "when an operator asks to set up test trees for an existing project and project SessionStart hooks load TEST_TREES.md and the tree-writing rules before coding agents work" {
  run cat "$SKILL"
  assert_output --partial '.contree/hooks/test-trees-session-start.sh'
  assert_output --partial 'cat TEST_TREES.md'
  assert_output --partial "tree-writing rules"
}

@test "when an operator asks to set up test trees for an existing project and project Stop hooks ask the coding agent to reconcile drift between trees, tests, and implementation before it finishes" {
  run cat "$SKILL"
  assert_output --partial '.contree/hooks/test-trees-on-stop.sh'
  assert_output --partial "reconcile drift between trees, tests, and implementation"
  assert_output --partial "before it finishes"
}

@test "when an operator asks to set up test trees for an existing project and both project configurations preserve existing hooks while receiving each test-tree hook exactly once" {
  run cat "$SKILL"
  assert_output --partial '.claude/settings.json'
  assert_output --partial '.codex/hooks.json'
  assert_output --partial "without replacing existing settings or hooks"
  assert_output --partial "Do not duplicate an equivalent"
}

@test "when an operator asks to set up test trees for an existing project and hook failures fail visibly without hiding their native output" {
  run cat "$SKILL"
  assert_output --partial "fails visibly with complete native output"
  assert_output --partial "exit 2"
}

@test "when an operator asks to set up test trees for an existing project and the skill proves both hooks through actual Claude Code and Codex turns before reporting completion" {
  run cat "$SKILL"
  assert_output --partial "For Claude Code and Codex separately"
  assert_output --partial "actual coding-agent SessionStart turn"
  assert_output --partial "actual coding-agent Stop turn"
  assert_output --partial "Do not report completion"
}

@test "when an operator asks to set up test trees for a new project then the skill creates an empty test-tree home without inventing behaviour" {
  run cat "$SKILL"
  assert_output --partial 'empty `TEST_TREES.md`'
  assert_output --partial "Do not invent behaviour"
  assert_output --partial "Do not create test files"
}

@test "when an operator asks to set up test trees for a new project and it installs and proves the same project-local steering hooks" {
  run cat "$SKILL"
  assert_output --partial "Install and prove the same project-local SessionStart and Stop hooks"
}
