#!/usr/bin/env bats

load test_helper

@test "change skill's frontmatter TRIGGERs on behaviour-change phrasings" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/change/SKILL.md"
  [[ "$output" == *"TRIGGER"* ]]
  [[ "$output" == *"behaviour change"* ]]
  [[ "$output" == *"before any code is discussed or written"* ]]
}

@test "sync skill's frontmatter TRIGGERs on drift/gaps/staleness phrasings" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/sync/SKILL.md"
  [[ "$output" == *"TRIGGER"* ]]
  [[ "$output" == *"drift"* ]]
  [[ "$output" == *"gaps"* ]]
  [[ "$output" == *"staleness"* ]]
}

@test "setup skill's frontmatter TRIGGERs when no framework or TEST_TREES.md exists" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/setup/SKILL.md"
  [[ "$output" == *"TRIGGER"* ]]
  [[ "$output" == *"no test framework"* ]]
  [[ "$output" == *"TEST_TREES.md"* ]]
}

@test "tdd skill's frontmatter TRIGGERs on implementing behaviour or writing tests" {
  run sed -n '/^---$/,/^---$/p' "$PROJECT_ROOT/skills/tdd/SKILL.md"
  [[ "$output" == *"TRIGGER"* ]]
  [[ "$output" == *"implementing behaviour"* ]]
  [[ "$output" == *"writing tests"* ]]
}

@test "session-start Directions block names each skill with its trigger" {
  run bash "$PROJECT_ROOT/hooks/session-start.sh"
  [[ "$output" == *"Directions"* ]]
  [[ "$output" == *"change"* ]]
  [[ "$output" == *"tdd"* ]]
  [[ "$output" == *"sync"* ]]
  [[ "$output" == *"setup"* ]]
  [[ "$output" == *"workflow"* ]]
}
