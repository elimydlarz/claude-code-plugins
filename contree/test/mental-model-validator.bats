#!/usr/bin/env bats

load test_helper

VALIDATOR="$PROJECT_ROOT/hooks/validate-mental-model.sh"

@test "validator flags that the file is missing when MENTAL_MODEL.md does not exist" {
  cd "$BATS_TEST_TMPDIR"
  run bash "$VALIDATOR"
  [[ "$output" == *"MENTAL_MODEL.md"* ]]
  [[ "$output" == *"missing"* || "$output" == *"not exist"* || "$output" == *"does not"* ]]
}

write_well_formed() {
  cat > "$1/MENTAL_MODEL.md" <<'EOF'
## Core Domain Identity

- placeholder

## World-to-Code Mapping

- placeholder

## Ubiquitous Language

- placeholder

## Bounded Contexts

- placeholder

## Invariants

- placeholder

## Decision Rationale

- placeholder

## Temporal View

- placeholder
EOF
}

@test "validator reports no issues when MENTAL_MODEL.md is well-formed" {
  cd "$BATS_TEST_TMPDIR"
  write_well_formed "$BATS_TEST_TMPDIR"
  run bash "$VALIDATOR"
  [ -z "$output" ]
}

@test "validator flags the overflow and names the section when Invariants exceeds its cap of 10" {
  cd "$BATS_TEST_TMPDIR"
  cat > MENTAL_MODEL.md <<'EOF'
## Core Domain Identity

- placeholder

## World-to-Code Mapping

- placeholder

## Ubiquitous Language

- placeholder

## Bounded Contexts

- placeholder

## Invariants

- one
- two
- three
- four
- five
- six
- seven
- eight
- nine
- ten
- eleven

## Decision Rationale

- placeholder

## Temporal View

- placeholder
EOF
  run bash "$VALIDATOR"
  [[ "$output" == *"Invariants"* ]]
  [[ "$output" == *"cap"* || "$output" == *"overflow"* || "$output" == *"exceed"* ]]
}
