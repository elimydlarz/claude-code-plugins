#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/change-without-me/SKILL.md"

@test "change-without-me skill directs change, sync, and tdd to run in sequence" {
  run cat "$SKILL"
  assert_output --partial "CHANGE"
  assert_output --partial "SYNC"
  assert_output --partial "TDD"
}

@test "change-without-me skill directs sync to run immediately after change completes" {
  run cat "$SKILL"
  assert_output --partial "sync"
  assert_output --partial "proceed directly"
}

@test "change-without-me skill directs tdd to implement each gap without pausing" {
  run cat "$SKILL"
  assert_output --partial "tdd"
  assert_output --partial "proceed directly to implementation"
}

@test "change-without-me skill expects all test trees to have passing tests when done" {
  run cat "$SKILL"
  [[ "$output" == *"passing tests"* ]]
}

@test "change-without-me skill directs second-opinion to review completed work after sync" {
  run cat "$SKILL"
  assert_output --partial "SECOND OPINION"
  assert_output --partial "second-opinion"
}

@test "change-without-me skill runs mutation testing at the end of the tdd phase" {
  run cat "$SKILL"
  assert_output --partial "### 3. TDD"
  assert_output --partial "Run mutation testing at the end"
}

@test "change-without-me skill routes second-opinion findings back through change, sync, or tdd" {
  run cat "$SKILL"
  assert_output --partial "### 4. SECOND OPINION"
  assert_output --partial "route them back through"
}
