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
  local cmd
  cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT="$input" PROJECT_DIR="$BATS_TEST_TMPDIR" CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" bash -c 'cd "$PROJECT_DIR" && printf "%s" "$INPUT" | bash -c "$CMD" 2>&1'
}

@test "when Claude stops after a response then a mental-model nudge prompts consideration of whether the task revealed any knowledge not already described in documentation, tests, and code, defaulting to no change" {
  run_hook '{}'
  assert_output --partial "knowledge"
  assert_output --partial "documentation, tests, and code"
  assert_output --partial "Default is no change"
}

@test "when Claude stops after a response then a mental-model nudge prompts consideration and directs creation of MENTAL_MODEL.md with the seven named H2 sections in order when it is missing at the project root" {
  rm -f "$BATS_TEST_TMPDIR/MENTAL_MODEL.md"
  run_hook '{}'
  assert_output --partial "MENTAL_MODEL.md is missing"
  assert_output --partial "Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, Temporal View"
}

@test "when Claude stops after a response then a mental-model nudge prompts consideration when a change is warranted then the edit declares which of the seven sections it belongs to" {
  run_hook '{}'
  assert_output --partial "name which of the seven sections it belongs to"
}

@test "when Claude stops after a response then a mental-model nudge prompts consideration when a change is warranted and an edit fitting no section is not added to the mental model" {
  run_hook '{}'
  assert_output --partial "if none fits, it is not part of the mental model"
}

@test "when Claude stops after a response then a mental-model nudge prompts consideration when a change is warranted and tightening an existing line is preferred over adding a new one" {
  run_hook '{}'
  assert_output --partial "prefer tightening an existing line over adding a new one"
}

@test "when Claude stops after a response then a mental-model nudge prompts consideration when a change is warranted and statements describe what is true, not what to avoid" {
  run_hook '{}'
  assert_output --partial "state what is true, not what to avoid"
}

@test "when Claude stops after a response then a mental-model nudge prompts consideration when a change is warranted and when the target section is at its cap, an existing item is displaced or merged rather than appended" {
  run_hook '{}'
  assert_output --partial "when the target section is at its cap, displace or merge an existing item rather than appending"
}

@test "when Claude stops after a response and a test-trees nudge prompts detection of drift between trees and implementation" {
  run_hook '{}'
  assert_output --partial "TEST TREES"
  assert_output --partial "drift"
}

@test "when Claude stops after a response and a claude-md nudge prompts detection of drift between CLAUDE.md content and reality" {
  run_hook '{}'
  assert_output --partial "CLAUDE.md"
  assert_output --partial "drift"
}

@test "when Claude stops after a response and a readme nudge prompts detection of readme staleness against what the project is, how consumers install it, configure it, and use it" {
  run_hook '{}'
  assert_output --partial "README"
  assert_output --partial "out of date"
  assert_output --partial "what the project is"
  assert_output --partial "install"
  assert_output --partial "configure"
  assert_output --partial "use"
}

@test "when Claude stops after a response and a readme nudge directs creation of README.md with those consumer-facing details when it is missing at the project root" {
  rm -f "$BATS_TEST_TMPDIR/README.md"
  run_hook '{}'
  assert_output --partial "README.md is missing"
  assert_output --partial "what the project is"
  assert_output --partial "install"
  assert_output --partial "configure"
  assert_output --partial "use"
}

@test "when Claude stops after a response and the hook fails with status 2 so the drift prompt reaches Claude" {
  run_hook '{}'
  [ "$status" -eq 2 ] || return 1
  assert_output --partial "TEST TREES"
}

@test "when stop_hook_active is true then the hook exits silently to prevent infinite loops" {
  run_hook '{"stop_hook_active": true}'
  [ "$status" -eq 0 ] || return 1
  assert_output ""
}

@test "when no nudge reports anything then Claude replies with 0" {
  run_hook '{}'
  assert_output --partial "If nothing needs attention, reply 0"
}

@test "if MENTAL_MODEL.md and README.md exist at the project root but the hook runs from a subdirectory then no missing-file nudge is emitted, because presence is judged at the project root rather than the hook's working directory" {
  mkdir -p "$BATS_TEST_TMPDIR/assets"
  local cmd
  cmd=$(hook_command)
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT='{}' CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" SUBDIR="$BATS_TEST_TMPDIR/assets" bash -c 'cd "$SUBDIR" && printf "%s" "$INPUT" | bash -c "$CMD" 2>&1'
  refute_output --partial "MENTAL_MODEL.md is missing"
  refute_output --partial "README.md is missing"
}

@test "when Codex runs the Stop hook without CLAUDE_PROJECT_DIR then the hook uses the current working directory as the project root" {
  local cmd
  cmd=$(hook_command)
  run env -u CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT='{}' PROJECT_DIR="$BATS_TEST_TMPDIR" bash -c 'cd "$PROJECT_DIR" && printf "%s" "$INPUT" | bash -c "$CMD" 2>&1'
  [ "$status" -eq 2 ] || return 1
  refute_output --partial "MENTAL_MODEL.md is missing"
  refute_output --partial "README.md is missing"
}

@test "when Codex runs the Stop hook without CLAUDE_PROJECT_DIR and emits the normal drift prompt instead of failing" {
  local cmd
  cmd=$(hook_command)
  run env -u CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CMD="$cmd" INPUT='{}' PROJECT_DIR="$BATS_TEST_TMPDIR" bash -c 'cd "$PROJECT_DIR" && printf "%s" "$INPUT" | bash -c "$CMD" 2>&1'
  [ "$status" -eq 2 ] || return 1
  assert_output --partial "TEST TREES"
  refute_output --partial "requires CLAUDE_PROJECT_DIR"
}
