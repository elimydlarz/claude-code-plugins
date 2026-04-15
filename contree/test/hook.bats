#!/usr/bin/env bats

load test_helper

hook_command() {
  jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
}

# Helper: run the hook command with given JSON input
run_hook() {
  local input="$1"
  local cmd; cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT="$input" \
    bash -c 'printf "%s" "$INPUT" | bash -c "$CMD" 2>&1'
}

# Helper: run the hook with a transcript file whose last assistant text is $1
run_hook_with_last_text() {
  local last_text="$1"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"
  jq -nc --arg text "$last_text" \
    '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$text}]}}' \
    > "$transcript"
  local input_file="$BATS_TEST_TMPDIR/input.json"
  printf '{"transcript_path":"%s"}' "$transcript" > "$input_file"
  local cmd; cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT_FILE="$input_file" \
    bash -c 'bash -c "$CMD" < "$INPUT_FILE" 2>&1'
}

# --- Loop prevention ---

@test "hook exits 0 when stop_hook_active is true" {
  run_hook '{"stop_hook_active": true}'
  [ "$status" -eq 0 ]
}

@test "hook exits 0 when stop_hook_active is true among other fields" {
  run_hook '{"stop_hook_active": true, "other": "data"}'
  [ "$status" -eq 0 ]
}

# --- Normal operation ---

@test "hook exits 2 when stop_hook_active is false" {
  run_hook '{"stop_hook_active": false}'
  [ "$status" -eq 2 ]
}

@test "hook exits 2 when stop_hook_active is absent" {
  run_hook '{}'
  [ "$status" -eq 2 ]
}

@test "hook exits 2 with empty input" {
  run_hook ''
  [ "$status" -eq 2 ]
}

# --- Review prompt content ---

@test "hook prompt mentions Requirements" {
  run_hook '{}'
  [[ "$output" == *"Requirements"* ]]
}

@test "hook prompt mentions test trees" {
  run_hook '{}'
  [[ "$output" == *"test trees"* ]]
}

@test "hook prompt mentions Mental Model" {
  run_hook '{}'
  [[ "$output" == *"Mental Model"* ]]
}

@test "hook prompt mentions drift" {
  run_hook '{}'
  [[ "$output" == *"drifted"* ]]
}

@test "hook prompt mentions never modify silently" {
  run_hook '{}'
  [[ "$output" == *"never modify them silently"* ]]
}

@test "hook prompt mentions CLAUDE.md" {
  run_hook '{}'
  [[ "$output" == *"CLAUDE.md"* ]]
}

@test "hook prompt mentions README.md" {
  run_hook '{}'
  [[ "$output" == *"README.md"* ]]
}

# --- Yield on question ---

@test "hook exits 0 silently when last assistant message ends with a question mark" {
  run_hook_with_last_text "Want me to do that?"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook exits 2 with drift prompt when last assistant message does not end with a question mark" {
  run_hook_with_last_text "Did the tests pass? Yes! Finished."
  [ "$status" -eq 2 ]
  [[ "$output" == *"drifted"* ]]
}

@test "hook yields when question mark is followed by trailing whitespace" {
  run_hook_with_last_text $'Want me to do that?\n\n'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
