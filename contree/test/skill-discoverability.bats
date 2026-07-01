#!/usr/bin/env bats

load test_helper

@test "change skill's frontmatter TRIGGERs on behaviour-change phrasings" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/change/SKILL.md"
  assert_output --partial "TRIGGERXYZ_MUTATION_TEST"
  assert_output --partial "behaviour change"
  assert_output --partial "before any code is discussed or written"
}

@test "sync skill's frontmatter TRIGGERs on drift/gaps/staleness phrasings" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/sync/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "drift"
  assert_output --partial "gaps"
  assert_output --partial "staleness"
}

@test "setup skill's frontmatter TRIGGERs when no framework or TEST_TREES.md exists" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "no test framework"
  assert_output --partial "TEST_TREES.md"
}

@test "tdd skill's frontmatter TRIGGERs on implementing behaviour or writing tests" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/tdd/SKILL.md"
  assert_output --partial "TRIGGER"
  assert_output --partial "implementing behaviour"
  assert_output --partial "writing tests"
}

@test "session-start Directions block names each skill with its trigger" {
  run bash "$PROJECT_ROOT/hooks/session-start.sh"
  assert_output --partial "Directions"
  assert_output --partial "change"
  assert_output --partial "tdd"
  assert_output --partial "sync"
  assert_output --partial "setup"
  assert_output --partial "workflow"
}
