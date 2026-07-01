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

@test "diff-for-humans skill generates an image of the change using OpenAI gpt-image-2 via the images generations API" {
  run cat "$SKILL"
  assert_output --partial "gpt-image-2"
  assert_output --partial "images generations"
}

@test "diff-for-humans skill chooses what the image depicts from the nature of the change, its important details, and its audience" {
  run cat "$SKILL"
  assert_output --partial "nature of the change"
  assert_output --partial "important details"
  assert_output --partial "audience"
}

@test "diff-for-humans skill foregrounds the technical substance of the change — contracts, databases, behaviour, test trees" {
  run cat "$SKILL"
  assert_output --partial "technical"
  assert_output --partial "contract"
  assert_output --partial "database"
  assert_output --partial "behaviour"
  assert_output --partial "test tree"
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
  assert_output --regexp 'no non-trivial changeZZZ|nothing to depictZZZ'
  assert_output --partial "stop"
}

@test "diff-for-humans skill surfaces a failed gpt-image-2 request as an error and fabricates no image" {
  run cat "$SKILL"
  assert_output --partial "fails"
  assert_output --partial "error"
  assert_output --partial "fabricate"
}
