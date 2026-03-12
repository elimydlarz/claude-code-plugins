#!/usr/bin/env bats

load test_helper

SETUP_SKILL="$PROJECT_ROOT/skills/setup-test-trees/SKILL.md"

# setup skill > process

@test "setup skill > process > then instructs setting up a changed-test runner" {
  run grep -i "changed.*test\|only.*changed\|run.*changed" "$SETUP_SKILL"
  assert_success
}

@test "setup skill > process > then instructs updating the project CLAUDE.md with test commands" {
  run grep -i "CLAUDE.md" "$SETUP_SKILL"
  assert_success
}
