#!/usr/bin/env bats

setup() {
  load 'test_helper'
}

# -- plugin.json --

@test "plugin.json is valid JSON" {
  run jq '.' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
}

@test "plugin.json has name openclaw-notifier" {
  run jq -r '.name' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
  assert_output "openclaw-notifier"
}

@test "plugin.json has a version" {
  run jq -r '.version' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
  refute_output "null"
}

@test "plugin.json has a description" {
  run jq -r '.description' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
  refute_output "null"
}

# -- hooks.json --

@test "hooks.json is valid JSON" {
  run jq '.' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
}

@test "hooks.json registers a SubagentStop hook" {
  run jq -r '.hooks.SubagentStop | length' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  assert_output "1"
}

@test "hook command points to scripts/notify.sh" {
  run jq -r '.hooks.SubagentStop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  assert_output --partial 'scripts/notify.sh'
}

# -- notify.sh --

@test "notify.sh has valid bash syntax" {
  run bash -n "$PROJECT_ROOT/scripts/notify.sh"
  assert_success
}

@test "notify.sh exits 0 when OPENCLAW_URL is unset" {
  run bash -c "unset OPENCLAW_URL; echo '{}' | '$PROJECT_ROOT/scripts/notify.sh'"
  assert_success
}
