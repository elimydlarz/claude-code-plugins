#!/usr/bin/env bats

load test_helper

VALIDATOR="$PROJECT_ROOT/hooks/validate-mental-model.sh"

@test "validator flags that the file is missing when MENTAL_MODEL.md does not exist" {
  cd "$BATS_TEST_TMPDIR"
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" bash "$VALIDATOR"
  [[ "$output" == *"MENTAL_MODEL.md"* ]]
  [[ "$output" == *"missing"* || "$output" == *"not exist"* || "$output" == *"does not"* ]]
}

@test "validator exits 0 even when issues are present (advisory, not blocking)" {
  cd "$BATS_TEST_TMPDIR"
  printf '## Glossary\n\n- one\n' > MENTAL_MODEL.md
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" bash "$VALIDATOR"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
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
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" bash "$VALIDATOR"
  [ -z "$output" ]
}

@test "validator flags the missing section when one of the seven named sections is absent" {
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

## Decision Rationale

- placeholder

## Temporal View

- placeholder
EOF
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" bash "$VALIDATOR"
  [[ "$output" == *"Invariants"* ]]
  [[ "$output" == *"missing"* || "$output" == *"absent"* ]]
}

@test "validator flags the rogue heading when an H2 is not one of the seven named sections" {
  cd "$BATS_TEST_TMPDIR"
  write_well_formed "$BATS_TEST_TMPDIR"
  printf '\n## Glossary\n\n- extra\n' >> MENTAL_MODEL.md
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" bash "$VALIDATOR"
  [[ "$output" == *"Glossary"* ]]
  [[ "$output" == *"rogue"* || "$output" == *"not one of"* || "$output" == *"unknown"* ]]
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
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR" bash "$VALIDATOR"
  [[ "$output" == *"Invariants"* ]]
  [[ "$output" == *"cap"* || "$output" == *"overflow"* || "$output" == *"exceed"* ]]
}
