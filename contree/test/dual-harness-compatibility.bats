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

# --- when the Stop hook fires ---

@test "then hooks.json wires it to hooks/stop-drift-check.sh" {
  run jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  assert_output --partial "stop-drift-check.sh"
}

@test "and the journey harness does not treat bare agent command-not-found output as a hook runner error" {
  run grep -F "hook.*command not found" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_failure

  run grep -F "|command not found|" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_failure
}

@test "and the journey harness does not treat Vitest hook timeout output as a hook runner error" {
  run grep -F "(SessionStart|Stop|PreToolUse|PostToolUse|UserPromptSubmit|Notification) hook \\(failed\\)" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F "hook .*failed" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_failure
}

@test "and the journey harness does not treat ordinary Codex apply_patch diagnostics as agent failure" {
  run grep -F '"(message|text)":"[^"]*(usage limit|rate limit)' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F 'grep -Eq '\''"turn\.failed"|usage limit|rate limit' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_failure
}

@test "and Claude journey runs do not require Codex auth docker arguments" {
  run grep -F 'docker_env_args=("${DOCKER_LLM_ENV[@]}")' "$PROJECT_ROOT/test/journey/docker-run.sh"
  assert_success

  run grep -F 'docker_env_args+=("${DOCKER_CODEX_ENV[@]}")' "$PROJECT_ROOT/test/journey/docker-run.sh"
  assert_success
}

@test "and Claude journey runs fail fast without Claude provider auth" {
  run grep -F "Claude harness requires ANTHROPIC_API_KEY or DEEPSEEK_API_KEY" "$PROJECT_ROOT/test/journey/docker-run.sh"
  assert_success
}
