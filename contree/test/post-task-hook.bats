#!/usr/bin/env bats

load test_helper

hook_command() {
  jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
}

run_hook() {
  local input="$1"
  local cmd; cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT="$input" \
    bash -c 'printf "%s" "$INPUT" | bash -c "$CMD" 2>&1'
}

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

# --- Prompt content (golden-file) ---
# If this fails: the drift-check prompt changed. Review the diff, then update
# test/fixtures/expected/stop-drift-check.out deliberately.

@test "hook emits the expected drift-check prompt" {
  local actual="$BATS_TEST_TMPDIR/actual"
  run bash -c 'printf "%s" "{}" | bash "$1" >/dev/null 2>"$2"' _ \
    "$PROJECT_ROOT/hooks/stop-drift-check.sh" "$actual"
  [ "$status" -eq 2 ]
  diff "$actual" "$PROJECT_ROOT/test/fixtures/expected/stop-drift-check.out"
}

# --- Yield on question ---

@test "hook exits 0 silently when last assistant message ends with a question mark" {
  run_hook_with_last_text "Want me to do that?"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook exits 2 and emits the prompt when last assistant message does not end with a question mark" {
  run_hook_with_last_text "Did the tests pass? Yes! Finished."
  [ "$status" -eq 2 ]
  [ -n "$output" ]
}

@test "hook yields when question mark is followed by trailing whitespace" {
  run_hook_with_last_text $'Want me to do that?\n\n'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook selects the last assistant text across multiple messages" {
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"
  {
    echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Statement one."}]}}'
    echo '{"type":"user","message":{"role":"user","content":"ok"}}'
    echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Ready to proceed?"}]}}'
  } > "$transcript"
  local input_file="$BATS_TEST_TMPDIR/input.json"
  printf '{"transcript_path":"%s"}' "$transcript" > "$input_file"
  local cmd; cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT_FILE="$input_file" \
    bash -c 'bash -c "$CMD" < "$INPUT_FILE" 2>&1'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
