#!/usr/bin/env bats

load test_helper

SCRIPT="$PROJECT_ROOT/hooks/self-care-20-20-20.sh"

setup() {
  heartbeat_dir="$BATS_TEST_TMPDIR/heartbeats"
  nudge_dir="$BATS_TEST_TMPDIR/nudges"
}

run_hook() {
  local input_file="$BATS_TEST_TMPDIR/input.json"
  echo '{}' > "$input_file"
  CONTREE_HEARTBEAT_DIR="$heartbeat_dir" CONTREE_NUDGE_DIR="$nudge_dir" \
    run bash "$SCRIPT" < "$input_file"
}

touch_heartbeat_seconds_ago() {
  local seconds_ago="$1"
  mkdir -p "$heartbeat_dir"
  touch "$heartbeat_dir/$(( $(date +%s) - seconds_ago ))"
}

touch_nudge_seconds_ago() {
  local seconds_ago="$1"
  mkdir -p "$nudge_dir"
  touch "$nudge_dir/$(( $(date +%s) - seconds_ago ))"
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

@test "does not nudge when a reminder was issued in the last 20 minutes" {
  touch_heartbeat_seconds_ago 1500
  touch_heartbeat_seconds_ago 60
  touch_nudge_seconds_ago 600  # 10 min ago — within 20 min window

  run_hook

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
