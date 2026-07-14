#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/diff-for-humans/SKILL.md"

@test "diff-for-humans skill determines the change to depict from any natural-language indication the user gave" {
  run cat "$SKILL"
  assert_output --regexp 'natural-language|natural language'
  assert_output --partial "indicat"
}

@test "diff-for-humans skill absent a clear indication depicts the last non-trivial, naturally grouped changes, not a single commit and not only the working tree" {
  run cat "$SKILL"
  assert_output --regexp 'naturally grouped|naturally-grouped'
  assert_output --partial "non-trivial"
  assert_output --partial "trunk-sync"
  assert_output --partial "commit"
  assert_output --partial "working tree"
}

@test "diff-for-humans skill gathers a change that includes new files not yet tracked by git" {
  run cat "$SKILL"
  [[ "$output" == *"untracked"* ]]
}

@test "diff-for-humans skill keeps untracked file diffs without treating git diff --no-index differences as recipe failure" {
  run cat "$SKILL"
  assert_output --partial 'git diff --no-index -- /dev/null "$f" || true'
}

@test "diff-for-humans skill generates an image of the change using OpenAI gpt-image-2 via the images generations API" {
  run cat "$SKILL"
  assert_output --partial "gpt-image-2"
  assert_output --partial "images generations"
  assert_output --partial "OPENAI_BASE_URL"
}

@test "diff-for-humans skill chooses what the image depicts from the nature of the change, its important details, and its audience" {
  run cat "$SKILL"
  assert_output --partial "nature of the change"
  assert_output --partial "important details"
  assert_output --partial "audience"
}

@test "diff-for-humans skill foregrounds the technical substance of the change — contracts, databases, behaviour, test trees — as concrete technical elements rather than only an abstract metaphor" {
  run cat "$SKILL"
  assert_output --partial "technical"
  assert_output --partial "contract"
  assert_output --partial "database"
  assert_output --partial "behaviour"
  assert_output --partial "test tree"
  assert_output --partial "abstract metaphor"
}

@test "diff-for-humans skill saves the returned image as a .png file" {
  run cat "$SKILL"
  assert_output --partial "save"
  assert_output --partial ".png"
}

@test "diff-for-humans skill surfaces those choices to the user for review" {
  run cat "$SKILL"
  assert_output --partial "surface"
  assert_output --partial "review"
}

@test "diff-for-humans skill says so and stops without calling the API when there are no non-trivial changes to depict" {
  run cat "$SKILL"
  assert_output --regexp 'no non-trivial change|nothing to depict'
  assert_output --partial "stop"
}

@test "if OPENAI_API_KEY is missing, the gpt-image-2 API returns an error or non-2xx response, the response contains no image, or the returned image is invalid then the failure is surfaced as an error and no image is fabricated" {
  run cat "$SKILL"
  assert_output --partial "fails"
  assert_output --partial "error"
  assert_output --partial "fabricate"
  assert_output --partial 'curl -sS -f'
  assert_output --partial 'OPENAI_API_KEY:?OPENAI_API_KEY is required'
  assert_output --partial "jq -er"
  assert_output --partial 'select(type == "string" and length > 0)'
  assert_output --partial 'mktemp'
  assert_output --partial '[ -s "$TEMP_IMAGE" ]'
  assert_output --partial 'mv "$TEMP_IMAGE" "$OUTPUT_IMAGE"'
}
