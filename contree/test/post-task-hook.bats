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

# --- Mental-model nudge ---

@test "mental-model nudge includes the 'not recoverable from code and tests' criterion" {
  run_hook '{}'
  [[ "$output" == *"not recover"* ]]
  [[ "$output" == *"code and tests"* ]]
}

@test "mental-model nudge includes the 'removal would cause a mistake' criterion" {
  run_hook '{}'
  [[ "$output" == *"removal"* ]]
  [[ "$output" == *"mistake"* ]]
  [[ "$output" == *"competent human"* ]]
}

@test "mental-model nudge defaults to no change" {
  run_hook '{}'
  [[ "$output" == *"default"* ]]
  [[ "$output" == *"no change"* ]]
}

@test "mental-model nudge requires declaring which of the seven sections the edit belongs to" {
  run_hook '{}'
  [[ "$output" == *"seven sections"* ]]
}

@test "mental-model nudge rejects edits that fit no section" {
  run_hook '{}'
  [[ "$output" == *"no section fits"* || "$output" == *"fits no section"* || "$output" == *"none fits"* ]]
}

@test "mental-model nudge prefers tightening existing lines over adding new ones" {
  run_hook '{}'
  [[ "$output" == *"tighten"* ]]
}

@test "mental-model nudge requires statements to describe what is true" {
  run_hook '{}'
  [[ "$output" == *"what is true"* ]]
  [[ "$output" == *"what to avoid"* ]]
}

@test "mental-model nudge requires displacement or merging at section cap" {
  run_hook '{}'
  [[ "$output" == *"cap"* ]]
  [[ "$output" == *"displace"* || "$output" == *"merg"* ]]
}

# --- Test-trees nudge ---

@test "test-trees nudge detects drift between trees and implementation" {
  run_hook '{}'
  [[ "$output" == *"test trees"* ]]
  [[ "$output" == *"drift"* || "$output" == *"drifted"* ]]
}

# --- CLAUDE.md nudge ---

@test "claude-md nudge detects drift between CLAUDE.md content and reality" {
  run_hook '{}'
  [[ "$output" == *"CLAUDE.md"* ]]
}

# --- Readme nudge ---

@test "readme nudge detects readme staleness" {
  run_hook '{}'
  [[ "$output" == *"readme"* ]]
}

# --- Yield on question ---

@test "hook exits 0 silently when last assistant message ends with a question mark" {
  run_hook_with_last_text "Want me to do that?"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook exits 2 with check prompt when last assistant message does not end with a question mark" {
  run_hook_with_last_text "Did the tests pass? Yes! Finished."
  [ "$status" -eq 2 ]
  [[ "$output" == *"drifted apart"* ]]
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
