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

# Mirrors the shape of real Claude Code transcripts:
# - lines 1-2 are bookkeeping entries with no timestamp
# - first timestamped line is the user entry on line 3
# - timestamps include fractional seconds and a Z suffix
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
  local input_file wrapper
  input_file=$(mktemp)
  wrapper=$(mktemp)
  printf '{"transcript_path":"%s"}' "$transcript" > "$input_file"
  printf '#!/usr/bin/env bash\nCONTREE_NUDGE_DIR=%q bash %q < %q 2>&1\n' \
    "$nudge_dir" "$SCRIPT" "$input_file" > "$wrapper"
  run bash "$wrapper"
  rm -f "$input_file" "$wrapper"
}

# --- Error handling ---

@test "exits 0 silently when nudge directory cannot be created" {
  local tmpdir; tmpdir=$(mktemp -d)
  local transcript="$tmpdir/transcript.jsonl"

  make_transcript "$transcript" "$(iso_minutes_ago 25)"
  # /dev/null is a file, so creating a subdir beneath it always fails
  run_hook "/dev/null/contree-nudges" "$transcript"

  [ "$status" -eq 0 ]
  [ -z "$output" ]

  rm -rf "$tmpdir"
}

# --- Repeat nudge (nudge file baseline) ---

@test "emits additionalContext JSON when 20 minutes have elapsed since the most recent nudge file" {
  local tmpdir; tmpdir=$(mktemp -d)
  local nudge_dir="$tmpdir/nudges/20-20-20"
  local transcript="$tmpdir/transcript.jsonl"

  mkdir -p "$nudge_dir"
  # Nudge file timestamped 25 minutes ago
  touch "$nudge_dir/$(( $(date +%s) - 1500 ))"
  # Session started 60 minutes ago (should not affect — nudge file takes precedence)
  make_transcript "$transcript" "$(iso_minutes_ago 60)"

  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"UserPromptSubmit"* ]]
  [[ "$output" == *"20-20-20"* ]]

  rm -rf "$tmpdir"
}

@test "does not require transcript file to exist when nudge file baseline is available" {
  local tmpdir; tmpdir=$(mktemp -d)
  local nudge_dir="$tmpdir/nudges/20-20-20"
  # Deliberately point at a transcript file that does NOT exist — mirrors `claude -p`
  # behaviour where UserPromptSubmit fires before the transcript is written.
  local transcript="$tmpdir/nonexistent.jsonl"

  mkdir -p "$nudge_dir"
  touch "$nudge_dir/$(( $(date +%s) - 1500 ))"

  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"20-20-20"* ]]

  rm -rf "$tmpdir"
}

@test "exits 0 when less than 20 minutes have elapsed since the most recent nudge file" {
  local tmpdir; tmpdir=$(mktemp -d)
  local nudge_dir="$tmpdir/nudges/20-20-20"
  local transcript="$tmpdir/transcript.jsonl"

  mkdir -p "$nudge_dir"
  # Nudge file timestamped 10 minutes ago
  touch "$nudge_dir/$(( $(date +%s) - 600 ))"
  make_transcript "$transcript" "$(iso_minutes_ago 60)"

  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]

  rm -rf "$tmpdir"
}

# --- First nudge (session start baseline) ---

@test "creates a nudge file when nudge fires" {
  local tmpdir; tmpdir=$(mktemp -d)
  local nudge_dir="$tmpdir/nudges/20-20-20"
  local transcript="$tmpdir/transcript.jsonl"

  make_transcript "$transcript" "$(iso_minutes_ago 25)"
  run_hook "$nudge_dir" "$transcript"

  [ "$(ls "$nudge_dir" | wc -l | tr -d ' ')" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "finds first timestamped entry when many bookkeeping lines precede it" {
  local tmpdir; tmpdir=$(mktemp -d)
  local nudge_dir="$tmpdir/nudges/20-20-20"
  local transcript="$tmpdir/transcript.jsonl"
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

  rm -rf "$tmpdir"
}

@test "emits additionalContext when 20 minutes have elapsed since session start in a realistic transcript" {
  local tmpdir; tmpdir=$(mktemp -d)
  local nudge_dir="$tmpdir/nudges/20-20-20"
  local transcript="$tmpdir/transcript.jsonl"

  make_realistic_transcript "$transcript" "$(iso_minutes_ago_millis 25)"
  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"20-20-20"* ]]

  rm -rf "$tmpdir"
}

@test "emits additionalContext with 20 feet and 20 seconds when nudge fires from session start" {
  local tmpdir; tmpdir=$(mktemp -d)
  local nudge_dir="$tmpdir/nudges/20-20-20"
  local transcript="$tmpdir/transcript.jsonl"

  make_transcript "$transcript" "$(iso_minutes_ago 25)"
  run_hook "$nudge_dir" "$transcript"

  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"UserPromptSubmit"* ]]
  [[ "$output" == *"20-20-20"* ]]
  [[ "$output" == *"20 feet"* ]]
  [[ "$output" == *"20 seconds"* ]]

  rm -rf "$tmpdir"
}
