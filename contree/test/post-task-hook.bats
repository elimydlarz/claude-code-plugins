#!/usr/bin/env bats

load test_helper

setup() {
  touch "$BATS_TEST_TMPDIR/MENTAL_MODEL.md"
  touch "$BATS_TEST_TMPDIR/README.md"
}

hook_command() {
  jq -r '.hooks.Stop[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
}

run_hook() {
  local input="$1"
  local cmd; cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT="$input" PROJECT_DIR="$BATS_TEST_TMPDIR" CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" \
    bash -c 'cd "$PROJECT_DIR" && printf "%s" "$INPUT" | bash -c "$CMD" 2>&1'
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
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT_FILE="$input_file" PROJECT_DIR="$BATS_TEST_TMPDIR" CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" \
    bash -c 'cd "$PROJECT_DIR" && bash -c "$CMD" < "$INPUT_FILE" 2>&1'
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

# --- Mental-model nudge: primary criteria ---

@test "mental-model nudge asks whether the task revealed knowledge not already in documentation, tests, and code" {
  run_hook '{}'
  assert_output --partial "knowledge"
  assert_output --partial "documentation, tests, and code"
}

@test "mental-model nudge defaults to no change" {
  run_hook '{}'
  assert_output --partial "Default"
  assert_output --partial "no change"
}

# --- Mental-model nudge: when a change is warranted ---

@test "mental-model nudge names the seven sections as the only accepted landing zones" {
  run_hook '{}'
  [[ "$output" == *"seven sections"* ]]
}

@test "mental-model nudge rejects edits that fit no section" {
  run_hook '{}'
  [[ "$output" == *"none fits"* || "$output" == *"no section fits"* ]]
}

@test "mental-model nudge prefers tightening existing lines over adding new ones" {
  run_hook '{}'
  [[ "$output" == *"tighten"* ]]
}

@test "mental-model nudge requires statements of what is true, not what to avoid" {
  run_hook '{}'
  assert_output --partial "what is true"
  assert_output --partial "avoid"
}

@test "mental-model nudge requires displacement or merge when a section is at its cap" {
  run_hook '{}'
  assert_output --partial "cap"
  assert_output --regexp 'displace|merg'
}

# --- Mental-model nudge: missing-file branch ---

@test "mental-model nudge directs creation of MENTAL_MODEL.md with the seven sections in order when the file is missing" {
  rm -f "$BATS_TEST_TMPDIR/MENTAL_MODEL.md"
  run_hook '{}'
  assert_output --partial "MENTAL_MODEL.md is missing"
  assert_output --partial "Core Domain Identity"
  assert_output --partial "World-to-Code Mapping"
  assert_output --partial "Ubiquitous Language"
  assert_output --partial "Bounded Contexts"
  assert_output --partial "Invariants"
  assert_output --partial "Decision Rationale"
  assert_output --partial "Temporal View"
}

# --- Test-trees nudge ---

@test "test-trees nudge prompts detection of drift between trees and implementation" {
  run_hook '{}'
  assert_output --regexp 'test trees|TEST TREES'
  assert_output --partial "drift"
}

# --- CLAUDE.md nudge ---

@test "claude-md nudge prompts detection of drift between CLAUDE.md content and reality" {
  run_hook '{}'
  assert_output --partial "CLAUDE.md"
  assert_output --partial "drift"
}

# --- README nudge ---

@test "readme nudge prompts detection of readme staleness" {
  run_hook '{}'
  [[ "$output" == *"readme"* || "$output" == *"README"* ]]
  [[ "$output" == *"out of date"* || "$output" == *"stale"* ]]
}

@test "readme nudge anchors staleness against what the project is, install, configure, and use" {
  run_hook '{}'
  [[ "$output" == *"what the project is"* ]]
  [[ "$output" == *"install"* ]]
  [[ "$output" == *"configure"* ]]
  [[ "$output" == *"use"* ]]
}

@test "readme nudge directs creation of README.md describing what the project is, install, configure, and use when the file is missing" {
  rm -f "$BATS_TEST_TMPDIR/README.md"
  run_hook '{}'
  [[ "$output" == *"README.md is missing"* ]]
  [[ "$output" == *"what the project is"* ]]
  [[ "$output" == *"install"* ]]
  [[ "$output" == *"configure"* ]]
  [[ "$output" == *"use"* ]]
}

# --- Question stop ---

@test "hook injects the question-stop prompt and exits 2 when last assistant message ends with a question mark" {
  run_hook_with_last_text "Want me to do that?"
  [ "$status" -eq 2 ]
  [ -n "$output" ]
}

@test "question-stop prompt replaces the drift nudges" {
  run_hook_with_last_text "Which way?"
  [[ "$output" != *"README"* ]]
  [[ "$output" != *"Default is no change"* ]]
}

@test "question-stop prompt directs checking the rules, mental model, and test trees for the answer" {
  run_hook_with_last_text "Which way?"
  [[ "$output" == *"Rules"* ]]
  [[ "$output" == *"mental model"* ]]
  [[ "$output" == *"test trees"* ]]
}

@test "question-stop prompt directs deciding and acting rather than asking when they determine the answer" {
  run_hook_with_last_text "Which way?"
  [[ "$output" == *"decide"* ]]
  [[ "$output" == *"not ask"* ]]
}

@test "question-stop prompt directs asking the user only when genuinely under-determined" {
  run_hook_with_last_text "Which way?"
  [[ "$output" == *"under-determined"* ]]
}

@test "hook exits 2 and emits the drift prompt when last assistant message does not end with a question mark" {
  run_hook_with_last_text "Did the tests pass? Yes! Finished."
  [ "$status" -eq 2 ]
  [[ "$output" == *"README"* ]]
}

@test "hook detects the question after trailing whitespace and injects the question-stop prompt" {
  run_hook_with_last_text $'Want me to do that?\n\n'
  [ "$status" -eq 2 ]
  [[ "$output" == *"under-determined"* ]]
}

@test "hook emits the prompt when earlier text ended with ? but the most recent assistant text is a statement" {
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"
  {
    echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Is this right?"}]}}'
    echo '{"type":"user","message":{"role":"user","content":"yes"}}'
    echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"OK done."}]}}'
  } > "$transcript"
  local input_file="$BATS_TEST_TMPDIR/input.json"
  printf '{"transcript_path":"%s"}' "$transcript" > "$input_file"
  local cmd; cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT_FILE="$input_file" CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" \
    bash -c 'bash -c "$CMD" < "$INPUT_FILE" 2>&1'
  [ "$status" -eq 2 ]
  [ -n "$output" ]
}

@test "hook emits the prompt when no assistant message has any text (tool_use only)" {
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"
  echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"ls"}}]}}' > "$transcript"
  local input_file="$BATS_TEST_TMPDIR/input.json"
  printf '{"transcript_path":"%s"}' "$transcript" > "$input_file"
  local cmd; cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT_FILE="$input_file" CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" \
    bash -c 'bash -c "$CMD" < "$INPUT_FILE" 2>&1'
  [ "$status" -eq 2 ]
  [ -n "$output" ]
}

@test "hook selects the last assistant text and injects the question-stop prompt when it ends with a question" {
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"
  {
    echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Statement one."}]}}'
    echo '{"type":"user","message":{"role":"user","content":"ok"}}'
    echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Ready to proceed?"}]}}'
  } > "$transcript"
  local input_file="$BATS_TEST_TMPDIR/input.json"
  printf '{"transcript_path":"%s"}' "$transcript" > "$input_file"
  local cmd; cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT_FILE="$input_file" CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" \
    bash -c 'bash -c "$CMD" < "$INPUT_FILE" 2>&1'
  [ "$status" -eq 2 ]
  [[ "$output" == *"under-determined"* ]]
}

@test "no missing-file nudge is emitted when MENTAL_MODEL.md and README.md exist at the project root but the hook runs from a subdirectory" {
  mkdir -p "$BATS_TEST_TMPDIR/assets"
  local cmd; cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT='{}' CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" SUBDIR="$BATS_TEST_TMPDIR/assets" \
    bash -c 'cd "$SUBDIR" && printf "%s" "$INPUT" | bash -c "$CMD" 2>&1'
  [[ "$output" != *"MENTAL_MODEL.md is missing"* ]]
  [[ "$output" != *"README.md is missing"* ]]
}
