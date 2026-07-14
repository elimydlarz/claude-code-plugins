#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/bootstrap-test-trees/SKILL.md"

@test "when the skill classifies a project then consumer-visible behaviour makes it existing while its absence makes it new" {
  run cat "$SKILL"
  assert_output --partial "consumer-visible behaviour"
  assert_output --partial "A project is existing"
  assert_output --partial "A project is new"
}

@test "when an operator asks to bootstrap test trees for an existing project then the skill runs setup-mental-model and setup-test-trees as focused prerequisite phases" {
  run cat "$SKILL"
  assert_output --partial 'Run `setup-mental-model` faithfully'
  assert_output --partial 'Run `setup-test-trees` faithfully'
}

@test "when an operator asks to bootstrap test trees for an existing project and it proves both project-local steering hooks are active before implementing tests" {
  run cat "$SKILL"
  assert_output --partial "SessionStart-hook"
  assert_output --partial "Stop-hook"
  assert_output --partial "before advancing"
  assert_output --partial "actual coding-agent turns"
}

@test "when an operator asks to bootstrap test trees for an existing project and operator agreement on the contract is required before test implementation starts" {
  run cat "$SKILL"
  assert_output --partial "After the operator has agreed the contract"
}

@test "when an operator asks to bootstrap test trees for an existing project and a second wave of subagents implements non-overlapping test trees as tests whose hierarchy mirrors each tree verbatim" {
  run cat "$SKILL"
  assert_output --partial "second wave of subagents regardless of project size"
  assert_output --partial "non-overlapping trees"
  assert_output --partial "hierarchy mirrors it verbatim"
}

@test "when an operator asks to bootstrap test trees for an existing project and each implementation subagent uses tdd at the tree's native seam, observes RED, updates coverage, and writes one uncommented real test at a time" {
  run cat "$SKILL"
  assert_output --partial 'uses `tdd`'
  assert_output --partial "native seam"
  assert_output --partial "observes RED"
  assert_output --partial "updates the tree's coverage path"
  assert_output --partial "writes one test at a time"
  assert_output --partial "placeholder, skipped, or fake tests"
  assert_output --partial "writes no comments"
}

@test "when an operator asks to bootstrap test trees for an existing project and every tree maps to exactly one uncommented test file" {
  run cat "$SKILL"
  assert_output --partial "one tree maps to exactly one test file"
  assert_output --partial "one test file maps to exactly one tree"
  assert_output --partial "uncommented test file"
}

@test "when an operator asks to bootstrap test trees for an existing project and the coding agent reconciles the test implementations and runs the normal and journey test commands" {
  run cat "$SKILL"
  assert_output --partial "Reconcile the implementations yourself"
  assert_output --partial "normal and journey test commands"
}

@test "when an operator asks to bootstrap test trees for a new project then the skill runs setup-mental-model and setup-test-trees to create their empty homes and project-local steering hooks" {
  run cat "$SKILL"
  assert_output --partial "created their empty homes"
  assert_output --partial "project-local steering hooks"
}

@test "when an operator asks to bootstrap test trees for a new project and it leaves behaviour trees and tests to be pulled into existence by the first requested capability" {
  run cat "$SKILL"
  assert_output --partial "Do not write behaviour trees or tests"
  assert_output --partial "first requested capability"
}

@test "if bootstrapped tests expose behaviour that disagrees with the operator's intended contract then the disagreement is left visible and routed through change or tdd rather than weakened in the trees or tests" {
  run cat "$SKILL"
  assert_output --partial "leave it visible"
  assert_output --partial '`change`'
  assert_output --partial '`tdd`'
  assert_output --partial "do not weaken trees"
}
