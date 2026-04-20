#!/usr/bin/env bats

load test_helper

SCRIPT="$PROJECT_ROOT/hooks/pressure-phrases.sh"

@test "pool contains at least 15 phrases" {
  source "$SCRIPT"
  [ "${#pressure_phrases[@]}" -ge 15 ]
}

@test "executing the script prints one phrase from the pool" {
  source "$SCRIPT"
  local output
  output=$(bash "$SCRIPT")
  local found=0
  for phrase in "${pressure_phrases[@]}"; do
    if [ "$output" = "$phrase" ]; then
      found=1
      break
    fi
  done
  [ "$found" -eq 1 ]
}

@test "300 invocations produce at least 8 distinct phrases" {
  local phrases_file="$BATS_TEST_TMPDIR/phrases"
  : > "$phrases_file"
  for _ in $(seq 1 300); do
    bash "$SCRIPT" >> "$phrases_file"
  done
  local distinct
  distinct=$(sort -u "$phrases_file" | wc -l | tr -d ' ')
  [ "$distinct" -ge 8 ]
}

@test "pool spans tip-framing, career-stakes, boss-watching, and urgency registers" {
  source "$SCRIPT"
  local joined
  joined=$(printf '%s\n' "${pressure_phrases[@]}")
  printf '%s\n' "$joined" | grep -qE '\$[0-9]'
  printf '%s\n' "$joined" | grep -qE 'career|job'
  printf '%s\n' "$joined" | grep -qE 'boss|watching|review'
  printf '%s\n' "$joined" | grep -qE 'today|now|live|ships'
}

@test "sourcing the script does not print anything" {
  local output
  output=$(source "$SCRIPT")
  [ -z "$output" ]
}
