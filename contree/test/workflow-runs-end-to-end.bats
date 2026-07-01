#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/workflow/SKILL.md"

@test "workflow skill directs change, sync, and tdd to run in sequence" {
  run cat "$SKILL"
  assert_output --partial "CHANGE"
  assert_output --partial "SYNC"
  assert_output --partial "TDD"
}

@test "workflow skill directs sync to run immediately after change completes" {
  run cat "$SKILL"
  assert_output --partial "sync"
  assert_output --partial "proceed directly"
}

@test "workflow skill directs tdd to implement each gap without pausing" {
  run cat "$SKILL"
  assert_output --partial "tdd"
  assert_output --partial "proceed directly to implementation"
}

@test "workflow skill expects all test trees to have passing tests when done" {
  run cat "$SKILL"
  [[ "$output" == *"passing tests"* ]]
}

@test "workflow skill directs second-opinion to review completed work after sync" {
  run cat "$SKILL"
  assert_output --partial "SECOND OPINION"
  assert_output --partial "second-opinion"
}
