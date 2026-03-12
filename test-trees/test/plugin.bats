#!/usr/bin/env bats

load test_helper

@test "plugin.json exists" {
  run test -f "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
}

@test "plugin.json contains plugin name" {
  run cat "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
  assert_output --partial '"name"'
}

@test "tdd skill exists" {
  run test -f "$PROJECT_ROOT/skills/tdd/SKILL.md"
  assert_success
}

@test "setup skill exists" {
  run test -f "$PROJECT_ROOT/skills/setup-test-trees/SKILL.md"
  assert_success
}
