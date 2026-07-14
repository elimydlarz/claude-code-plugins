#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/bootstrap-test-trees/SKILL.md"

@test "when an operator bootstraps an existing project then focused mental-model and test-tree setup run before test implementation" {
  run cat "$SKILL"
  assert_output --partial 'Run `setup-mental-model` faithfully'
  assert_output --partial 'Run `setup-test-trees` faithfully'
  assert_output --partial "SessionStart-hook"
  assert_output --partial "Stop-hook"
  assert_output --partial "before advancing"
}

@test "when bootstrap composes focused setup then the coordinator proves retained steering instead of abandoning a whole skill in the background" {
  run cat "$SKILL"
  assert_output --partial "Invoke both focused skills yourself"
  assert_output --partial "unattended background agent"
  assert_output --partial "subagent summary is not proof"
  assert_output --partial ".claude/settings.json"
  assert_output --partial ".codex/hooks.json"
}

@test "when focused steering is established then later coding agents receive the model and trees while working plus drift feedback before finishing" {
  run cat "$SKILL"
  assert_output --partial "actual coding-agent turns"
  assert_output --partial "receive both the mental model and test trees while they work"
  assert_output --partial "drift feedback before they finish"
}

@test "when an existing project is bootstrapped then a required second subagent wave implements non-overlapping trees through tdd" {
  run cat "$SKILL"
  assert_output --partial "second wave of subagents regardless of project size"
  assert_output --partial "non-overlapping trees"
  assert_output --partial 'uses `tdd`'
  assert_output --partial "observes RED"
}

@test "when test implementation completes then every tree owns exactly one uncommented mirrored test file" {
  run cat "$SKILL"
  assert_output --partial "one tree maps to exactly one test file"
  assert_output --partial "one test file maps to exactly one tree"
  assert_output --partial "writes no comments"
  assert_output --partial "hierarchy mirrors it verbatim"
}

@test "when existing-project bootstrap completes then the coordinator reconciles implementations and runs normal and functional commands" {
  run cat "$SKILL"
  assert_output --partial "Reconcile the implementations yourself"
  assert_output --partial "normal and functional test commands"
  assert_output --partial "leave it visible"
  assert_output --partial '`change`'
  assert_output --partial '`tdd`'
}

@test "when a new project is bootstrapped then focused setup creates empty homes and steering without inventing behaviour" {
  run cat "$SKILL"
  assert_output --partial "created their empty homes"
  assert_output --partial "project-local steering hooks"
  assert_output --partial "Do not write behaviour trees or tests"
  assert_output --partial "first requested capability"
}
