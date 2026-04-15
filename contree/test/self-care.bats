#!/usr/bin/env bats

load test_helper

SCRIPT="$PROJECT_ROOT/hooks/self-care-20-20-20.sh"

iso_minutes_ago() {
  local minutes="$1"
  if date -v-1M >/dev/null 2>&1; then
    date -u -v-"${minutes}M" +"%Y-%m-%dT%H:%M:%SZ"
  else
    date -u -d "${minutes} minutes ago" +"%Y-%m-%dT%H:%M:%SZ"
  fi
}

make_transcript() {
  local path="$1" ts="$2"
  echo '{"timestamp":"'"$ts"'","type":"user","message":"hello"}' > "$path"
}

make_realistic_transcript() {
  local path="$1" ts="$2"
  {
    echo '{"type":"permission-mode","timestamp":null}'
    echo '{"type":"file-history-snapshot","timestamp":null}'
    echo '{"type":"user","timestamp":"'"$ts"'","message":"hello"}'
  } > "$path"
}

iso_minutes_ago_millis() {
  local minutes="$1"
  if date -v-1M >/dev/null 2>&1; then
    date -u -v-"${minutes}M" +"%Y-%m-%dT%H:%M:%S.000Z"
  else
    date -u -d "${minutes} minutes ago" +"%Y-%m-%dT%H:%M:%S.000Z"
  fi
}

run_hook() {
  local nudge_dir="$1" transcript="$2"
  local input_file="$BATS_TEST_TMPDIR/input.json"
  local wrapper="$BATS_TEST_TMPDIR/wrapper.sh"
  printf '{"transcript_path":"%s"}' "$transcript" > "$input_file"
  printf '#!/usr/bin/env bash\nCONTREE_NUDGE_DIR=%q bash %q < %q 2>&1\n' \
    "$nudge_dir" "$SCRIPT" "$input_file" > "$wrapper"
  run bash "$wrapper"
}

run_hook_stdout() {
  local nudge_dir="$1" transcript="$2"
  local input_file="$BATS_TEST_TMPDIR/input.json"
  local wrapper="$BATS_TEST_TMPDIR/wrapper.sh"
  printf '{"transcript_path":"%s"}' "$transcript" > "$input_file"
  printf '#!/usr/bin/env bash\nCONTREE_NUDGE_DIR=%q bash %q < %q 2>/dev/null\n' \
    "$nudge_dir" "$SCRIPT" "$input_file" > "$wrapper"
  run bash "$wrapper"
}

# --- Error handling ---

@test "exits 0 silently when nudge directory cannot be created" {
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"

  make_transcript "$transcript" "$(iso_minutes_ago 25)"
  run_hook "/dev/null/contree-nudges" "$transcript"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- JSON contract ---

@test "stdout is valid hookSpecificOutput JSON with correct structure" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"

  make_transcript "$transcript" "$(iso_minutes_ago 25)"
  run_hook_stdout "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  echo "$output" | jq empty
  local event_name; event_name=$(echo "$output" | jq -r '.hookSpecificOutput.hookEventName')
  [ "$event_name" = "UserPromptSubmit" ]
  local ctx; ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"20-20-20"* ]]
  [[ "$ctx" == *"20 feet"* ]]
  [[ "$ctx" == *"20 seconds"* ]]
}

@test "emits no stdout when not nudging" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"

  mkdir -p "$nudge_dir"
  touch "$nudge_dir/$(( $(date +%s) - 600 ))"
  make_transcript "$transcript" "$(iso_minutes_ago 60)"

  run_hook_stdout "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- Repeat nudge (nudge file baseline) ---

@test "emits additionalContext JSON when 20 minutes have elapsed since the most recent nudge file" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"

  mkdir -p "$nudge_dir"
  touch "$nudge_dir/$(( $(date +%s) - 1500 ))"
  make_transcript "$transcript" "$(iso_minutes_ago 60)"

  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"UserPromptSubmit"* ]]
  [[ "$output" == *"20-20-20"* ]]
}

@test "does not require transcript file to exist when nudge file baseline is available" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/nonexistent.jsonl"

  mkdir -p "$nudge_dir"
  touch "$nudge_dir/$(( $(date +%s) - 1500 ))"

  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"20-20-20"* ]]
}

@test "exits 0 when less than 20 minutes have elapsed since the most recent nudge file" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"

  mkdir -p "$nudge_dir"
  touch "$nudge_dir/$(( $(date +%s) - 600 ))"
  make_transcript "$transcript" "$(iso_minutes_ago 60)"

  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
}

# --- First nudge (session start baseline) ---

@test "creates a nudge file when nudge fires" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"

  make_transcript "$transcript" "$(iso_minutes_ago 25)"
  run_hook "$nudge_dir" "$transcript"

  [ "$(ls "$nudge_dir" | wc -l | tr -d ' ')" -eq 1 ]
}

@test "finds first timestamped entry when many bookkeeping lines precede it" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"
  local ts; ts=$(iso_minutes_ago_millis 25)

  {
    for _ in 1 2 3 4 5 6 7 8; do
      echo '{"type":"bookkeeping","timestamp":null}'
    done
    echo '{"type":"user","timestamp":"'"$ts"'","message":"hello"}'
  } > "$transcript"

  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"20-20-20"* ]]
}

@test "emits additionalContext when 20 minutes have elapsed since session start in a realistic transcript" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"

  make_realistic_transcript "$transcript" "$(iso_minutes_ago_millis 25)"
  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"20-20-20"* ]]
}

@test "emits additionalContext with 20 feet and 20 seconds when nudge fires from session start" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"

  make_transcript "$transcript" "$(iso_minutes_ago 25)"
  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"UserPromptSubmit"* ]]
  [[ "$output" == *"20-20-20"* ]]
  [[ "$output" == *"20 feet"* ]]
  [[ "$output" == *"20 seconds"* ]]
}

# --- Prior-session nudge files do not trigger a nudge ---

@test "does not nudge when session started recently even if a prior-session nudge file is older than 20 minutes" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"

  mkdir -p "$nudge_dir"
  touch "$nudge_dir/$(( $(date +%s) - 1500 ))"
  make_transcript "$transcript" "$(iso_minutes_ago 5)"

  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" != *"additionalContext"* ]]
  [[ "$output" != *"20-20-20"* ]]
}

@test "nudges after 20 minutes since session start even if a prior-session nudge file is older" {
  local nudge_dir="$BATS_TEST_TMPDIR/nudges/20-20-20"
  local transcript="$BATS_TEST_TMPDIR/transcript.jsonl"

  mkdir -p "$nudge_dir"
  touch "$nudge_dir/$(( $(date +%s) - 3600 ))"
  make_transcript "$transcript" "$(iso_minutes_ago 25)"

  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"20-20-20"* ]]
}
