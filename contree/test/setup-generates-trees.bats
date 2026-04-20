#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup skill instructs to add a CLAUDE.md pointer to TEST_TREES.md if missing" {
  run grep -qE "pointer.*TEST_TREES|TEST_TREES.*pointer|CLAUDE\.md.*(identif|point).*TEST_TREES" "$SKILL"
  assert_success
}
