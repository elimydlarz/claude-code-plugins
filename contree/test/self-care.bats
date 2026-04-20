#!/usr/bin/env bats

load test_helper

SCRIPT="$PROJECT_ROOT/hooks/self-care-20-20-20.sh"

setup() {
  heartbeat_dir="$BATS_TEST_TMPDIR/heartbeats"
  nudge_dir="$BATS_TEST_TMPDIR/nudges"
  SETUP_NOW=$(date +%s)
}

run_hook() {
  local input_file="$BATS_TEST_TMPDIR/input.json"
  echo '{}' > "$input_file"
  CONTREE_HEARTBEAT_DIR="$heartbeat_dir" CONTREE_NUDGE_DIR="$nudge_dir" CONTREE_NOW="$SETUP_NOW" \
    run bash "$SCRIPT" < "$input_file"
}

touch_heartbeat_seconds_ago() {
  local seconds_ago="$1"
  mkdir -p "$heartbeat_dir"
  touch "$heartbeat_dir/$(( SETUP_NOW - seconds_ago ))"
}

touch_nudge_seconds_ago() {
  local seconds_ago="$1"
  mkdir -p "$nudge_dir"
  touch "$nudge_dir/$(( SETUP_NOW - seconds_ago ))"
}

@test "records a heartbeat when the hook fires" {
  run_hook
  [ "$status" -eq 0 ]
  [ "$(ls "$heartbeat_dir" | wc -l | tr -d ' ')" -eq 1 ]
}

@test "exits silently when the heartbeat record fails" {
  heartbeat_dir="/dev/null/cannot-create-here"
  run_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prunes heartbeats older than one hour when recording" {
  local old_ts; old_ts=$(( SETUP_NOW - 7200 ))
  mkdir -p "$heartbeat_dir"
  touch "$heartbeat_dir/$old_ts"

  run_hook

  [ "$status" -eq 0 ]
  [ ! -f "$heartbeat_dir/$old_ts" ]
}

@test "keeps heartbeats newer than one hour when recording" {
  local recent_ts; recent_ts=$(( SETUP_NOW - 1800 ))
  mkdir -p "$heartbeat_dir"
  touch "$heartbeat_dir/$recent_ts"

  run_hook

  [ "$status" -eq 0 ]
  [ -f "$heartbeat_dir/$recent_ts" ]
}

@test "does not nudge when no prior heartbeats exist" {
  run_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "nudges when heartbeats span at least 20 minutes with no gap longer than 5 minutes" {
  touch_heartbeat_seconds_ago 1500  # 25 min ago
  touch_heartbeat_seconds_ago 1200  # 20 min ago
  touch_heartbeat_seconds_ago 900   # 15 min ago
  touch_heartbeat_seconds_ago 600   # 10 min ago
  touch_heartbeat_seconds_ago 300   # 5 min ago
  touch_heartbeat_seconds_ago 60    # 1 min ago

  run_hook

  [ "$status" -eq 0 ]
  echo "$output" | jq empty
  [ "$(echo "$output" | jq -r '.hookSpecificOutput.hookEventName')" = "UserPromptSubmit" ]
  local ctx; ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$ctx" == *"20-20-20"* ]]
  [[ "$ctx" == *"20 feet"* ]]
  [[ "$ctx" == *"20 seconds"* ]]
}

@test "does not nudge when the stretch is 1 second below the 20-minute threshold" {
  touch_heartbeat_seconds_ago 1199
  touch_heartbeat_seconds_ago 900
  touch_heartbeat_seconds_ago 600
  touch_heartbeat_seconds_ago 300
  touch_heartbeat_seconds_ago 60

  run_hook

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "does not nudge when a gap longer than 5 minutes breaks the stretch" {
  # 30+ min of heartbeats but with a 10-min gap 10 min ago — stretch is only 10 min long
  touch_heartbeat_seconds_ago 1800
  touch_heartbeat_seconds_ago 1500
  touch_heartbeat_seconds_ago 1200
  touch_heartbeat_seconds_ago 900
  # gap 900s → 600s = 5 min, OK; but 900 → 300 = 10 min gap
  touch_heartbeat_seconds_ago 300
  touch_heartbeat_seconds_ago 60

  run_hook

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "does not nudge when a reminder was issued in the last 20 minutes" {
  touch_heartbeat_seconds_ago 1500
  touch_heartbeat_seconds_ago 1200
  touch_heartbeat_seconds_ago 900
  touch_heartbeat_seconds_ago 600
  touch_heartbeat_seconds_ago 300
  touch_heartbeat_seconds_ago 60
  touch_nudge_seconds_ago 600  # 10 min ago — within 20 min window

  run_hook

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits silently when the reminder record fails" {
  touch_heartbeat_seconds_ago 1500
  touch_heartbeat_seconds_ago 1200
  touch_heartbeat_seconds_ago 900
  touch_heartbeat_seconds_ago 600
  touch_heartbeat_seconds_ago 300
  touch_heartbeat_seconds_ago 60
  nudge_dir="/dev/null/cannot-create-here"

  run_hook

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
