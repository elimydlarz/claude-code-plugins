#!/usr/bin/env bats

load test_helper

HOOK="$PROJECT_ROOT/hooks/post-update-check.sh"

run_hook_for_file() {
  local project="$1"
  local file_path="$2"
  local input
  input=$(jq -nc --arg fp "$file_path" '{tool_name:"Edit", tool_input:{file_path:$fp}}')
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" INPUT="$input" PROJECT="$project" \
    bash -c 'cd "$PROJECT" && printf "%s" "$INPUT" | bash "'"$HOOK"'"'
}

@test "post-update hook surfaces validator findings when MENTAL_MODEL.md is edited and has issues" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  printf '## Glossary\n\n- one\n' > "$project/MENTAL_MODEL.md"
  run_hook_for_file "$project" "$project/MENTAL_MODEL.md"
  [[ "$output" == *"Glossary"* ]]
}
