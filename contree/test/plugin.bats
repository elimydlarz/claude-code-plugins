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

@test "setup skill exists" {
  run test -f "$PROJECT_ROOT/skills/setup/SKILL.md"
  assert_success
}

@test "change skill exists" {
  run test -f "$PROJECT_ROOT/skills/change/SKILL.md"
  assert_success
}

@test "sync skill exists" {
  run test -f "$PROJECT_ROOT/skills/sync/SKILL.md"
  assert_success
}

@test "workflow skill exists" {
  run test -f "$PROJECT_ROOT/skills/workflow/SKILL.md"
  assert_success
}

# --- Skill frontmatter (generic validator) ---

@test "every SKILL.md has non-empty name and description" {
  run bash "$PROJECT_ROOT/scripts/validate-skill-frontmatter.sh" "$PROJECT_ROOT/skills"
  assert_success
  [ -z "$output" ]
}

# --- Tree quality ---

@test "change skill instructs against tautological then clauses" {
  run grep -q "assert something.*when clause does not already imply\|restate.*condition\|tautolog" "$PROJECT_ROOT/skills/change/SKILL.md"
  assert_success
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

@test "hooks.json defines a SessionStart hook" {
  run jq -r '.hooks.SessionStart' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  refute_output "null"
}

@test "SessionStart hook emits the rules on stdout" {
  CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" run bash "$PROJECT_ROOT/hooks/session-start.sh"
  assert_success
  assert_output --partial "**KISS**"
  assert_output --partial "**Test layers**"
}

@test "hooks.json defines a UserPromptSubmit hook" {
  run jq -r '.hooks.UserPromptSubmit' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  refute_output "null"
}

@test "UserPromptSubmit hook points to self-care-20-20-20.sh" {
  run jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  assert_output --partial "self-care-20-20-20.sh"
}

@test "self-care-20-20-20.sh exists" {
  run test -f "$PROJECT_ROOT/hooks/self-care-20-20-20.sh"
  assert_success
}

@test "SessionStart hook points to session-start.sh" {
  run jq -r '.hooks.SessionStart[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  assert_output --partial "session-start.sh"
}

@test "session-start.sh exists" {
  run test -f "$PROJECT_ROOT/hooks/session-start.sh"
  assert_success
}
