#!/usr/bin/env bats

load test_helper

# Helper: run the hook command with given JSON input
run_hook() {
  local input="$1"
  # Extract command from hooks.json and run it with input on stdin
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  # Redirect stderr to stdout so bats can capture the prompt
  run bash -c "echo '$input' | bash -c '$cmd' 2>&1"
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
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  run env CMD="$cmd" INPUT_FILE="$input_file" bash -c 'bash -c "$CMD" < "$INPUT_FILE" 2>&1'
}

# --- Loop prevention ---

@test "hook exits 0 when stop_hook_active is true" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  echo '{"stop_hook_active": true}' | bash -c "$cmd" 2>/dev/null
  # If we get here without error, exit was 0
}

@test "hook exits 0 when stop_hook_active is true among other fields" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  echo '{"stop_hook_active": true, "other": "data"}' | bash -c "$cmd" 2>/dev/null
}

# --- Normal operation ---

@test "hook exits 2 when stop_hook_active is false" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  run bash -c 'echo "{\"stop_hook_active\": false}" | bash -c '"'"''"$cmd"''"'"' 2>&1'
  [ "$status" -eq 2 ]
}

@test "hook exits 2 when stop_hook_active is absent" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  run bash -c 'echo "{}" | bash -c '"'"''"$cmd"''"'"' 2>&1'
  [ "$status" -eq 2 ]
}

@test "hook exits 2 with empty input" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  run bash -c 'echo "" | bash -c '"'"''"$cmd"''"'"' 2>&1'
  [ "$status" -eq 2 ]
}

# --- Review prompt content ---

@test "hook prompt mentions Requirements" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"Requirements"* ]]
}

@test "hook prompt mentions test trees" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"test trees"* ]]
}

@test "hook prompt mentions Mental Model" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"Mental Model"* ]]
}

@test "hook prompt mentions drift" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"drifted"* ]]
}

@test "hook prompt mentions never modify silently" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"never modify them silently"* ]]
}

@test "hook prompt mentions CLAUDE.md" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"CLAUDE.md"* ]]
}

@test "hook prompt mentions README.md" {
  local cmd
  cmd=$(jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json")
  local output
  output=$(echo '{}' | bash -c "$cmd" 2>&1 || true)
  [[ "$output" == *"README.md"* ]]
}

# --- Yield on question ---

@test "hook exits 0 silently when last assistant message ends with a question mark" {
  run_hook_with_last_text "Want me to do that?"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
