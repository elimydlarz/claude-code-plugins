#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/diff-for-humans/SKILL.md"

@test "when the diff-for-humans skill is invoked then it determines the change to depict from any natural-language indication the user gave" {
  run cat "$SKILL"
  assert_output --regexp 'natural-language|natural language'
  assert_output --partial "indicat"
}

@test "when the diff-for-humans skill is invoked and absent a clear indication it depicts the last non-trivial, naturally grouped changes — not a single commit, since trunk-sync commits continuously, and not only the working tree" {
  run cat "$SKILL"
  assert_output --regexp 'naturally grouped|naturally-grouped'
  assert_output --partial "non-trivial"
  assert_output --partial "trunk-sync"
  assert_output --partial "commit"
  assert_output --partial "working tree"
}

@test "when the diff-for-humans skill is invoked and the change it gathers includes new files not yet tracked by git" {
  run cat "$SKILL"
  [[ "$output" == *"untracked"* ]]
}

@test "when the diff-for-humans skill is invoked and untracked file diffs do not make the recipe fail when git diff --no-index reports differences" {
  run cat "$SKILL"
  assert_output --partial 'git diff --no-index -- /dev/null "$f" || true'
}

@test "when the diff-for-humans skill is invoked and it generates an image representing that change using OpenAI's gpt-image-2 model via the images generations API, with OPENAI_BASE_URL selecting the API root" {
  run cat "$SKILL"
  assert_output --partial "gpt-image-2"
  assert_output --partial "images generations"
  assert_output --partial "OPENAI_BASE_URL"
}

@test "when the diff-for-humans skill is invoked and it chooses what the image depicts from the nature of the change, its important details, and its intended audience" {
  run cat "$SKILL"
  assert_output --partial "nature of the change"
  assert_output --partial "important details"
  assert_output --partial "audience"
}

@test "when the diff-for-humans skill is invoked and it foregrounds the technical substance the change touches — contracts, data and databases, behaviour, and test trees — as concrete technical elements rather than only an abstract metaphor" {
  run cat "$SKILL"
  assert_output --partial "technical"
  assert_output --partial "contract"
  assert_output --partial "database"
  assert_output --partial "behaviour"
  assert_output --partial "test tree"
  assert_output --partial "abstract metaphor"
}

@test "when the diff-for-humans skill is invoked and it saves the returned image as a .png file" {
  run cat "$SKILL"
  assert_output --partial "save"
  assert_output --partial ".png"
}

@test "when the diff-for-humans skill is invoked and it surfaces those choices to the user for review" {
  run cat "$SKILL"
  assert_output --partial "surface"
  assert_output --partial "review"
}

@test "when there are no non-trivial changes to depict then it says so and stops without calling the API" {
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
