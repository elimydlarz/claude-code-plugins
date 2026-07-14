#!/usr/bin/env bats

load test_helper

@test "when contree is installed under either Claude Code or Codex then a manifest exists at .claude-plugin/plugin.json" {
  run test -f "$PROJECT_ROOT/.claude-plugin/plugin.json"
  assert_success
}

@test "when contree is installed under either Claude Code or Codex and a manifest exists at .codex-plugin/plugin.json declaring skills as ./skills/ and hooks as ./hooks/hooks.json" {
  run test -f "$PROJECT_ROOT/.codex-plugin/plugin.json"
  assert_success

  run jq -r '.skills' "$PROJECT_ROOT/.codex-plugin/plugin.json"
  assert_success
  assert_output "./skills/"

  run jq -r '.hooks' "$PROJECT_ROOT/.codex-plugin/plugin.json"
  assert_success
  assert_output "./hooks/hooks.json"
}

@test "when Codex is the harness then Codex installations require [features].hooks and [features].plugin_hooks to be true so hooks/hooks.json is loaded" {
  run grep -F "[features].hooks = true" "$PROJECT_ROOT/CLAUDE.md"
  assert_success

  run grep -F "[features].plugin_hooks = true" "$PROJECT_ROOT/CLAUDE.md"
  assert_success

  run grep -F "hooks = true" "$PROJECT_ROOT/README.md"
  assert_success

  run grep -F "plugin_hooks = true" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success
}

@test "when contree is installed under either Claude Code or Codex and both manifests carry the same name and version" {
  claude_name=$(jq -r '.name' "$PROJECT_ROOT/.claude-plugin/plugin.json")
  codex_name=$(jq -r '.name' "$PROJECT_ROOT/.codex-plugin/plugin.json")
  [ "$claude_name" = "$codex_name" ]

  claude_version=$(jq -r '.version' "$PROJECT_ROOT/.claude-plugin/plugin.json")
  codex_version=$(jq -r '.version' "$PROJECT_ROOT/.codex-plugin/plugin.json")
  [ "$claude_version" = "$codex_version" ]
}

@test "when contree is installed under either Claude Code or Codex and .claude-plugin/plugin.json declares a name of \"contree\", a version, and a description" {
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

@test "when contree is installed under either Claude Code or Codex and one hooks/hooks.json is shared by both harnesses" {
  run test -f "$PROJECT_ROOT/hooks/hooks.json"
  assert_success

  run jq -r '.hooks' "$PROJECT_ROOT/.codex-plugin/plugin.json"
  assert_output "./hooks/hooks.json"
}

@test "when a hook fires then hooks.json invokes its script via \$CLAUDE_PLUGIN_ROOT — the env var both harnesses set" {
  commands=$(jq -r '[.. | objects | .command? // empty] | .[]' "$PROJECT_ROOT/hooks/hooks.json")
  [ -n "$commands" ]
  while IFS= read -r cmd; do
    [[ "$cmd" == *'${CLAUDE_PLUGIN_ROOT}'* ]] || { echo "command does not resolve via \$CLAUDE_PLUGIN_ROOT: $cmd"; false; }
  done <<< "$commands"
}

@test "when the Stop hook fires then hooks.json wires it to hooks/stop-drift-check.sh" {
  run jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
  assert_success
  assert_output --partial "stop-drift-check.sh"
}

@test "when Codex is the harness and the journey harness distinguishes hook runner failures from ordinary agent command failures" {
  run grep -F "hook.*command not found" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_failure

  run grep -F "|command not found|" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_failure
}

@test "when Codex is the harness and the journey harness distinguishes hook runner failures from test framework hook timeout output" {
  run grep -F "(SessionStart|Stop|PreToolUse|PostToolUse|UserPromptSubmit|Notification) hook \\(failed\\)" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F "hook .*failed" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_failure
}

@test "when Codex is the harness and the journey harness distinguishes structured Codex failures from ordinary transcript text and recoverable tool diagnostics" {
  run grep -F '"(message|text)":"[^"]*(usage limit|rate limit)' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F 'grep -Eq '\''"turn\.failed"|usage limit|rate limit' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_failure
}

@test "when the functional journey suite runs under either Claude Code or Codex then its coding-agent model calls are sent to OpenAI's Responses API authenticated with OPENAI_API_KEY" {
  run grep -F 'DOCKER_LLM_ENV=(-e OPENAI_API_KEY)' "$PROJECT_ROOT/test/journey/docker-run.sh"
  assert_success

  run grep -F 'model_provider = "openai-custom"' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F '[model_providers.openai-custom]' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F '[model_providers.openai]' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_failure

  run grep -F 'base_url = "https://api.openai.com/v1"' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F 'env_key = "OPENAI_API_KEY"' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F 'wire_api = "responses"' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F 'https://api.openai.com/v1/responses' "$PROJECT_ROOT/test/journey/claude-openai-responses-proxy.mjs"
  assert_success

  run grep -F 'Bearer ${apiKey}' "$PROJECT_ROOT/test/journey/claude-openai-responses-proxy.mjs"
  assert_success
}

@test "when the functional journey suite runs under either Claude Code or Codex and its coding agent uses gpt-5.6-luna with medium reasoning effort" {
  run grep -F 'model = "gpt-5.6-luna"' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F 'model_reasoning_effort = "medium"' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F 'CLAUDE_CODE_EFFORT_LEVEL="medium"' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F "model: 'gpt-5.6-luna'" "$PROJECT_ROOT/test/journey/claude-openai-responses-proxy.mjs"
  assert_success

  run grep -F "reasoning: { effort: 'medium' }" "$PROJECT_ROOT/test/journey/claude-openai-responses-proxy.mjs"
  assert_success
}

@test "if a functional journey run under either harness lacks OPENAI_API_KEY then it fails before starting the coding agent" {
  run grep -F "Functional journey runs require OPENAI_API_KEY" "$PROJECT_ROOT/test/journey/docker-run.sh"
  assert_success

  run grep -F "Functional journey runs require OPENAI_API_KEY" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success
}

@test "when Claude Code is the harness then standard functional journey agent turns have a \$5 budget ceiling" {
  run grep -F 'local max_budget_usd="5.00"' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success
}

@test "when Codex is the harness and the automated journey matrix runs the existing functional cases under Codex" {
  for journey in setup test-kinds-workflow describe-it-drift diff-images second-opinion; do
    run grep -F "\"$journey:codex\"" "$PROJECT_ROOT/test/journey/docker-run.sh"
    assert_success
  done
}

@test "when Codex is the harness and the journey harness treats unavailable Codex tools as functional failures when a scenario forbids them" {
  run grep -F "request_user_input is unavailable" "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success

  run grep -F 'acts_without_asking="FAIL' "$PROJECT_ROOT/test/journey/docker-entrypoint.sh"
  assert_success
}
