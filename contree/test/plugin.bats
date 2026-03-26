#!/usr/bin/env bats

load test_helper

# --- Plugin manifest ---

@test "plugin.json exists" {
  run test -f "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
}

@test "plugin.json is valid JSON" {
  run jq '.' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
}

@test "plugin.json has name 'contree'" {
  run jq -r '.name' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
  assert_output "contree"
}

@test "plugin.json has version" {
  run jq -r '.version' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
  refute_output "null"
}

@test "plugin.json has description" {
  run jq -r '.description' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
  refute_output "null"
}

# --- Skills ---

@test "tdd skill exists" {
  run test -f "$PROJECT_ROOT/skills/tdd/SKILL.md"
  assert_success
}

@test "setup-contree skill exists" {
  run test -f "$PROJECT_ROOT/skills/setup-contree/SKILL.md"
  assert_success
}

@test "sync-to-requirements skill exists" {
  run test -f "$PROJECT_ROOT/skills/sync-to-requirements/SKILL.md"
  assert_success
}

# --- Skill frontmatter ---

@test "tdd skill has name in frontmatter" {
  run head -5 "$PROJECT_ROOT/skills/tdd/SKILL.md"
  assert_output --partial 'name: tdd'
}

@test "tdd skill auto-triggers on behaviour changes" {
  run head -5 "$PROJECT_ROOT/skills/tdd/SKILL.md"
  assert_output --partial 'TRIGGER when'
}

@test "setup-contree skill has name in frontmatter" {
  run head -5 "$PROJECT_ROOT/skills/setup-contree/SKILL.md"
  assert_output --partial 'name: setup-contree'
}

@test "setup-contree skill auto-triggers on missing requirements" {
  run head -5 "$PROJECT_ROOT/skills/setup-contree/SKILL.md"
  assert_output --partial 'TRIGGER when'
}

@test "sync-to-requirements skill has name in frontmatter" {
  run head -5 "$PROJECT_ROOT/skills/sync-to-requirements/SKILL.md"
  assert_output --partial 'name: sync-to-requirements'
}

# --- Hook ---

@test "hooks.json exists" {
  run test -f "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
}

@test "hooks.json is valid JSON" {
  run jq '.' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
}

@test "hooks.json defines a Stop hook" {
  run jq -r '.hooks.Stop' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  refute_output "null"
}
