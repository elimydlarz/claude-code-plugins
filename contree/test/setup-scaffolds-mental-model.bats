#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

@test "setup skill instructs to create MENTAL_MODEL.md with seven H2 sections when it does not exist" {
  run grep -qE "MENTAL_MODEL\.md.*seven.*(section|H2)|seven.*(section|H2).*MENTAL_MODEL" "$SKILL"
  assert_success
}
