#!/usr/bin/env bats

load test_helper

VALIDATOR="$PROJECT_ROOT/hooks/validate-mental-model.sh"

@test "validator flags that the file is missing when MENTAL_MODEL.md does not exist" {
  cd "$BATS_TEST_TMPDIR"
  run bash "$VALIDATOR"
  [[ "$output" == *"MENTAL_MODEL.md"* ]]
  [[ "$output" == *"missing"* || "$output" == *"not exist"* || "$output" == *"does not"* ]]
}
