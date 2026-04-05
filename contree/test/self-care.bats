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

# --- First nudge (session start baseline) ---

@test "exits 2 and emits 20-20-20 nudge when 20 minutes have elapsed since session start" {
  local tmpdir; tmpdir=$(mktemp -d)
  local nudge_dir="$tmpdir/nudges/20-20-20"
  local transcript="$tmpdir/transcript.jsonl"

  make_transcript "$transcript" "$(iso_minutes_ago 25)"

  run bash "$SCRIPT" \
    <<< '{"transcript_path":"'"$transcript"'"}' \
    2>&1
  # merge stderr into stdout for bats capture; check exit separately
  CONTREE_NUDGE_DIR="$nudge_dir" run bash -c \
    'bash "'"$SCRIPT"'" 2>&1' \
    <<< '{"transcript_path":"'"$transcript"'"}'

  [ "$status" -eq 2 ]
  [[ "$output" == *"20-20-20"* ]]
  [[ "$output" == *"20 feet"* ]]

  rm -rf "$tmpdir"
}
