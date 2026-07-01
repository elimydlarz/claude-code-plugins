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
  [[ "$output" == *"gpt-image-2"* ]]
  [[ "$output" == *"images generations"* ]]
}

@test "diff-for-humans skill chooses what the image depicts from the nature of the change, its important details, and its audience" {
  run cat "$SKILL"
  [[ "$output" == *"nature of the change"* ]]
  [[ "$output" == *"important details"* ]]
  [[ "$output" == *"audience"* ]]
}

@test "diff-for-humans skill foregrounds the technical substance of the change — contracts, databases, behaviour, test trees" {
  run cat "$SKILL"
  [[ "$output" == *"technical"* ]]
  [[ "$output" == *"contract"* ]]
  [[ "$output" == *"database"* ]]
  [[ "$output" == *"behaviour"* ]]
  [[ "$output" == *"test tree"* ]]
}

@test "diff-for-humans skill saves the returned image as a .png file" {
  run cat "$SKILL"
  [[ "$output" == *"save"* ]]
  [[ "$output" == *".png"* ]]
}

@test "diff-for-humans skill surfaces those choices to the user for review" {
  run cat "$SKILL"
  [[ "$output" == *"surface"* ]]
  [[ "$output" == *"review"* ]]
}

@test "diff-for-humans skill says so and stops without calling the API when there are no non-trivial changes to depict" {
  run cat "$SKILL"
  [[ "$output" == *"no non-trivial change"* || "$output" == *"nothing to depict"* ]]
  [[ "$output" == *"stop"* ]]
}

@test "diff-for-humans skill surfaces a failed gpt-image-2 request as an error and fabricates no image" {
  run cat "$SKILL"
  [[ "$output" == *"fails"* ]]
  [[ "$output" == *"error"* ]]
  [[ "$output" == *"fabricate"* ]]
}
