#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/workflow/SKILL.md"

@test "workflow skill directs change, sync, and tdd to run in sequence" {
  run cat "$SKILL"
  [[ "$output" == *"CHANGE"* ]]
  [[ "$output" == *"SYNC"* ]]
  [[ "$output" == *"TDD"* ]]
}

@test "workflow skill directs sync to run immediately after change completes" {
  run cat "$SKILL"
  [[ "$output" == *"sync"* ]]
  [[ "$output" == *"proceed directly"* ]]
}

@test "workflow skill directs tdd to implement each gap without pausing" {
  run cat "$SKILL"
  [[ "$output" == *"tdd"* ]]
  [[ "$output" == *"proceed directly to implementation"* ]]
}

@test "workflow skill expects all test trees to have passing tests when done" {
  run cat "$SKILL"
  [[ "$output" == *"passing tests"* ]]
}
