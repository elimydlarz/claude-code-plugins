#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup skill instructs to add a CLAUDE.md pointer to TEST_TREES.md if missing" {
  run grep -qE "pointer.*TEST_TREES|TEST_TREES.*pointer|CLAUDE\.md.*(identif|point).*TEST_TREES" "$SKILL"
  assert_success
}

@test "setup skill instructs to write trees to TEST_TREES.md" {
  run grep -qE "[Ww]rite.*trees.*TEST_TREES\.md|trees.*writ.*TEST_TREES\.md|TEST_TREES\.md.*contains.*trees" "$SKILL"
  assert_success
}

@test "setup skill does not instruct writing a ## Test Trees section into CLAUDE.md" {
  run grep -qE '## Test Trees.*CLAUDE\.md|CLAUDE\.md.*## Test Trees|Write the trees into `## Test Trees` in CLAUDE' "$SKILL"
  assert_failure
}
