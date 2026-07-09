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

@test "and Codex installations enable hooks and plugin_hooks so hooks/hooks.json is loaded" {
  run grep -F "[features].hooks = true" "$PROJECT_ROOT/CLAUDE.md"
  assert_success

  run grep -F "[features].plugin_hooks = true" "$PROJECT_ROOT/CLAUDE.md"
  assert_success

  run grep -F "hooks = true" "$PROJECT_ROOT/README.md"
  assert_success

  run grep -F "plugin_hooks = true" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success
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
  assert_output "Edit|Write|MultiEdit|apply_patch"
}

@test "and the PostToolUse hook accepts Codex apply_patch stdin" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf '## Glossary\n\n- one\n' > "$project/MENTAL_MODEL.md"
  local input
  input=$(jq -nc --arg patch $'*** Begin Patch\n*** Update File: MENTAL_MODEL.md\n@@\n-old\n+new\n*** End Patch\n' '{tool_name:"apply_patch", tool_input:{command:$patch}}')

  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CLAUDE_PROJECT_DIR="$project" INPUT="$input" \
    bash -c 'printf "%s" "$INPUT" | bash "$CLAUDE_PLUGIN_ROOT/hooks/post-update-check.sh"'
  assert_success
  assert_output --partial "PostToolUse"
}

# --- when the Stop hook fires ---

@test "then hooks.json wires it to hooks/stop-drift-check.sh" {
  run jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  assert_output --partial "stop-drift-check.sh"
}
