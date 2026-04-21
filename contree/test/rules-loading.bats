#!/usr/bin/env bats

load test_helper

HOOKS_JSON="$PROJECT_ROOT/hooks/hooks.json"
SCRIPT="$PROJECT_ROOT/hooks/session-start.sh"

@test "session-start.sh emits a Rules section with the coding rules" {
  run cat "$SCRIPT"
  [[ "$output" == *"# Rules"* ]]
  [[ "$output" == *"KISS"* ]]
}

@test "session-start.sh is wired to the SessionStart hook event" {
  run jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS_JSON"
  [[ "$output" == *"session-start.sh"* ]]
}

@test "session-start.sh is not wired to any per-response hook event" {
  for event in UserPromptSubmit Stop PostToolUse PreToolUse SubagentStop; do
    run jq -r --arg e "$event" '.hooks[$e] // [] | [.[].hooks[].command] | map(select(test("session-start.sh"))) | length' "$HOOKS_JSON"
    [ "$output" = "0" ]
  done
}
