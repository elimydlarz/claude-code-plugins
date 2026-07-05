#!/usr/bin/env bats

load test_helper

# --- when contree is installed under either Claude Code or Codex ---

@test "then a manifest exists at .claude-plugin/plugin.json" {
  run test -f "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
}

@test "and a manifest exists at .codex-plugin/plugin.json declaring skills as ./skills/ and hooks as ./hooks/hooks.json" {
  run test -f "$PROJECT_ROOT/.codex-plugin/plugin.json"
  assert_success

  run jq -r '.skills' "$PROJECT_ROOT/.codex-plugin/plugin.json"
  assert_success
  assert_output "./skills/"

  run jq -r '.hooks' "$PROJECT_ROOT/.codex-plugin/plugin.json"
  assert_success
  assert_output "./hooks/hooks.json"
}

@test "and both manifests carry the same name and version" {
  claude_name=$(jq -r '.name' "$PROJECT_ROOT/.claude-plugin/plugin.json")
  codex_name=$(jq -r '.name' "$PROJECT_ROOT/.codex-plugin/plugin.json")
  [ "$claude_name" = "$codex_name" ]

  claude_version=$(jq -r '.version' "$PROJECT_ROOT/.claude-plugin/plugin.json")
  codex_version=$(jq -r '.version' "$PROJECT_ROOT/.codex-plugin/plugin.json")
  [ "$claude_version" = "$codex_version" ]
}

@test "and .claude-plugin/plugin.json declares a name of \"contree\", a version, and a description" {
  run jq -r '.name' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
  assert_output "contree"

  run jq -r '.version' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
  refute_output "null"

  run jq -r '.description' "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
  refute_output "null"
}

@test "and one hooks/hooks.json is shared by both harnesses" {
  run test -f "$PROJECT_ROOT/hooks/hooks.json"
  assert_success

  run jq -r '.hooks' "$PROJECT_ROOT/.codex-plugin/plugin.json"
  assert_output "./hooks/hooks.json"
}

# --- when a hook fires ---

@test "then hooks.json invokes its script via \$CLAUDE_PLUGIN_ROOT — the env var both harnesses set" {
  commands=$(jq -r '[.. | objects | .command? // empty] | .[]' "$PROJECT_ROOT/hooks/hooks.json")
  [ -n "$commands" ]
  while IFS= read -r cmd; do
    [[ "$cmd" == *'${CLAUDE_PLUGIN_ROOT}'* ]] || { echo "command does not resolve via \$CLAUDE_PLUGIN_ROOT: $cmd"; false; }
  done <<< "$commands"
}

# --- when an Edit, Write, MultiEdit, or apply_patch tool call completes ---

@test "then the PostToolUse matcher fires" {
  run jq -r '.hooks.PostToolUse[0].matcher' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  assert_output "Edit|Write|MultiEdit"
}

# --- when the Stop hook fires ---

@test "then hooks.json wires it to hooks/stop-drift-check.sh" {
  run jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  assert_output --partial "stop-drift-check.sh"
}
