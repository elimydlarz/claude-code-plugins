#!/usr/bin/env bats

load test_helper

HOOKS_JSON="$PROJECT_ROOT/hooks/hooks.json"
SCRIPT="$PROJECT_ROOT/hooks/session-start.sh"

@test "when a session starts then the rules list is shown" {
  run cat "$SCRIPT"
  assert_output --partial "# Rules"
  assert_output --partial "KISS"
}

@test "when a session starts and hooks.json wires session-start.sh to the SessionStart hook event" {
  run jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS_JSON"
  [[ "$output" == *"session-start.sh"* ]]
}

@test "when a session starts and not repeated on every response" {
  for event in Stop PostToolUse PreToolUse SubagentStop; do
    run jq -r --arg e "$event" '.hooks[$e] // [] | [.[].hooks[].command] | map(select(test("session-start.sh"))) | length' "$HOOKS_JSON"
    [ "$output" = "0" ]
  done
}
