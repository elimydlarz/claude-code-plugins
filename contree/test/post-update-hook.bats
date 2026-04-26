#!/usr/bin/env bats

load test_helper

HOOK="$PROJECT_ROOT/hooks/post-update-check.sh"

run_hook_for_file() {
  local project="$1"
  local file_path="$2"
  local tool_name="${3:-Edit}"
  local input
  input=$(jq -nc --arg tn "$tool_name" --arg fp "$file_path" '{tool_name:$tn, tool_input:{file_path:$fp}}')
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" CLAUDE_PROJECT_DIR="$project" INPUT="$input" \
    bash -c 'printf "%s" "$INPUT" | bash "'"$HOOK"'"'
}

@test "post-update hook surfaces validator findings when MENTAL_MODEL.md is edited and has issues" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf '## Glossary\n\n- one\n' > "$project/MENTAL_MODEL.md"
  run_hook_for_file "$project" "$project/MENTAL_MODEL.md"
  [[ "$output" == *"Glossary"* ]]
}

@test "post-update hook surfaces findings via additionalContext JSON" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf '## Glossary\n\n- one\n' > "$project/MENTAL_MODEL.md"
  run_hook_for_file "$project" "$project/MENTAL_MODEL.md"
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"PostToolUse"* ]]
}

@test "post-update hook does not run validator when a file other than MENTAL_MODEL.md is edited" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf '## Glossary\n\n- one\n' > "$project/MENTAL_MODEL.md"
  run_hook_for_file "$project" "$project/some-other-file.md"
  [ -z "$output" ]
}

@test "hooks.json wires post-update-check.sh as a PostToolUse hook" {
  run jq -r '.hooks.PostToolUse[0].hooks[0].command' "$PROJECT_ROOT/hooks/hooks.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"post-update-check.sh"* ]]
}

@test "post-update hook does not run validator for adjacent files like MENTAL_MODEL_DRAFT.md" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf '## Glossary\n\n- one\n' > "$project/MENTAL_MODEL.md"
  run_hook_for_file "$project" "$project/MENTAL_MODEL_DRAFT.md"
  [ -z "$output" ]
}

@test "post-update hook runs validator when MENTAL_MODEL.md is written (tool_name Write)" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf '## Glossary\n\n- one\n' > "$project/MENTAL_MODEL.md"
  run_hook_for_file "$project" "$project/MENTAL_MODEL.md" "Write"
  [[ "$output" == *"Glossary"* ]]
}

@test "post-update hook runs validator when MENTAL_MODEL.md is written via MultiEdit" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf '## Glossary\n\n- one\n' > "$project/MENTAL_MODEL.md"
  run_hook_for_file "$project" "$project/MENTAL_MODEL.md" "MultiEdit"
  [[ "$output" == *"Glossary"* ]]
}
