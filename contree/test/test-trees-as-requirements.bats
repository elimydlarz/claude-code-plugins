#!/usr/bin/env bats

load test_helper

@test "TEST_TREES.md exists at repo root" {
  [ -f "$PROJECT_ROOT/TEST_TREES.md" ]
}

@test "CLAUDE.md identifies TEST_TREES.md as the definition of functional and cross-functional requirements" {
  run cat "$PROJECT_ROOT/CLAUDE.md"
  [[ "$output" == *"TEST_TREES.md"* ]]
  [[ "$output" == *"functional and cross-functional requirements"* ]]
}

@test "TEST_TREES.md defines functional requirements using EARS syntax" {
  run cat "$PROJECT_ROOT/TEST_TREES.md"
  [[ "$output" == *"when"* ]]
  [[ "$output" == *"then"* ]]
}

@test "each behavioural unit has its own tree as a flat H2 subsection" {
  run grep -cE "^## [a-z-]+" "$PROJECT_ROOT/TEST_TREES.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 10 ]
}

@test "trees are flat subsections — no grouping H1s inside TEST_TREES.md" {
  run grep -c "^# " "$PROJECT_ROOT/TEST_TREES.md"
  [ "$output" -eq 0 ]
}

@test "change skill directs that the tree must exist before implementation starts" {
  run cat "$PROJECT_ROOT/skills/change/SKILL.md"
  [[ "$output" == *"Before implementation"* || "$output" == *"trees first, code second"* || "$output" == *"before any code is discussed or written"* ]]
}

@test "EARS rule is embedded in the change skill" {
  run cat "$PROJECT_ROOT/skills/change/SKILL.md"
  [[ "$output" == *"EARS"* ]]
  [[ "$output" == *"when"* ]]
  [[ "$output" == *"while"* ]]
  [[ "$output" == *"where"* ]]
}

@test "EARS rule is embedded in the tdd skill" {
  run cat "$PROJECT_ROOT/skills/tdd/SKILL.md"
  [[ "$output" == *"EARS"* ]]
}

@test "tdd skill directs updating the tree when implementation reveals new understanding" {
  run cat "$PROJECT_ROOT/skills/tdd/SKILL.md"
  [[ "$output" == *"add new cases as you discover them"* || "$output" == *"add newly discovered cases"* ]]
}

@test "every tree in TEST_TREES.md names its coverage in parenthesised labelled pairs" {
  # Tree name line must contain (...) with at least one recognised label,
  # drawn from: src, unit, integration, functional.
  local file="$PROJECT_ROOT/TEST_TREES.md"
  local missing=()
  while IFS= read -r tree; do
    [ -z "$tree" ] && continue
    local first_line
    first_line=$(awk -v h="## $tree" '
      $0 == h { in_section = 1; next }
      in_section && /^```/ { in_block = !in_block; next }
      in_section && in_block && NF { print; exit }
    ' "$file")
    if ! [[ "$first_line" == *"("*")"* ]]; then
      missing+=("$tree (no parens)")
      continue
    fi
    if ! [[ "$first_line" =~ \((src|unit|integration|functional):[[:space:]] ]]; then
      missing+=("$tree (no labelled pair)")
    fi
  done < <(grep -E "^## [a-z-]+" "$file" | sed 's/^## //')

  if [ ${#missing[@]} -gt 0 ]; then
    printf 'Trees with non-conforming path declarations:\n'
    printf '  - %s\n' "${missing[@]}"
    false
  fi
}
