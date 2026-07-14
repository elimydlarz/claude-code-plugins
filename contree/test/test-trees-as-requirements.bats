#!/usr/bin/env bats

load test_helper

@test "when a project uses contree then CLAUDE.md identifies TEST_TREES.md as the definition of functional and cross-functional requirements" {
  run cat "$PROJECT_ROOT/CLAUDE.md"
  assert_output --partial "TEST_TREES.md"
  assert_output --partial "functional and cross-functional requirements"
}

@test "when a project uses contree and TEST_TREES.md defines functional requirements using EARS syntax" {
  run cat "$PROJECT_ROOT/TEST_TREES.md"
  assert_output --partial "when"
  assert_output --partial "then"
}

@test "when a project uses contree and each behavioural unit has its own tree in TEST_TREES.md" {
  run grep -cE "^## [a-z-]+" "$PROJECT_ROOT/TEST_TREES.md"
  assert_success
  [ "$output" -ge 10 ] || return 1
}

@test "when a project uses contree and trees are flat subsections — not grouped by kind or layer" {
  run grep -c "^# " "$PROJECT_ROOT/TEST_TREES.md"
  [ "$output" -eq 0 ] || return 1
}

@test "when a project uses contree and every tree reifies exactly one test file" {
  local file="$PROJECT_ROOT/TEST_TREES.md"
  run bash -c "awk '/^(Journey|System|Component|Adapter|Use-case|Domain|Port): / { print }' '$file' | while IFS= read -r tree; do count=0; for label in domain use-case adapter component system journey; do value=\$(printf '%s\\n' \"\$tree\" | sed -nE \"s/.*(^|[;( ])\$label: ([^;)]+).*/\\2/p\"); [ -z \"\$value\" ] || count=\$((count + 1)); done; [ \"\$count\" -eq 1 ] || { printf '%s\\n' \"\$tree\"; exit 1; }; done"
  assert_success
}

@test "when a project uses contree and every test file reifies exactly one tree" {
  local file="$PROJECT_ROOT/TEST_TREES.md"
  run bash -c "grep -oE '(domain|use-case|adapter|component|system|journey): [^;)]+' '$file' | sed -E 's/^[a-z-]+: //' | sort | uniq -d"
  assert_success
  assert_output ""
}

@test "when a project uses contree and every tree begins with a Journey, System, Component, Adapter, Use-case, Domain, or Port layer" {
  local file="$PROJECT_ROOT/TEST_TREES.md"
  run awk '/^```$/ { block = !block; next } block && /^[A-Za-z-]+: / && !/^(Journey|System|Component|Adapter|Use-case|Domain|Port): / { print }' "$file"
  assert_success
  assert_output ""
}

@test "when a project uses contree and every tree names its coverage in parenthesised labelled pairs on the tree-name line, covering the categories src, domain, use-case, adapter, component, system, journey" {
  local file="$PROJECT_ROOT/TEST_TREES.md"
  run bash -c "awk '/^(Journey|System|Component|Adapter|Use-case|Domain|Port): / { print }' '$file' | while IFS= read -r tree; do printf '%s\\n' \"\$tree\" | grep -Eq '\\((src|domain|use-case|adapter|component|system|journey): [^)]+' || { printf '%s\\n' \"\$tree\"; exit 1; }; done"
  assert_success
}

@test "when a project uses contree and gaps are declared explicitly — \"none\" for expected-but-uncovered categories, omission for not-applicable ones" {
  local file="$PROJECT_ROOT/TEST_TREES.md"
  run bash -c "grep -oE '(src|domain|use-case|adapter|component|system|journey): [^;)]+' '$file' | sed -E 's/^[a-z-]+: //'"
  assert_success
  local value
  while IFS= read -r value; do
    [ "$value" = "none" ] || [[ "$value" =~ ^[A-Za-z0-9_./*,\ -]+$ ]] || return 1
  done <<< "$output"
}

@test "when a project uses contree and every declared coverage path exists on disk unless its value is none" {
  local file="$PROJECT_ROOT/TEST_TREES.md"
  run bash -c "grep -oE '(src|domain|use-case|adapter|component|system|journey): [^;)]+' '$file' | sed -E 's/^[a-z-]+: //' | tr ',' '\\n' | sed -E 's/^ +| +$//g' | while IFS= read -r path; do [ \"\$path\" = none ] || [ -e '$PROJECT_ROOT/'\"\$path\" ] || { printf '%s\\n' \"\$path\"; exit 1; }; done"
  assert_success
}

@test "when a project uses contree and the EARS rule is embedded where trees are written" {
  run cat "$PROJECT_ROOT/skills/change/SKILL.md"
  assert_output --partial "EARS"
  assert_output --partial "when"
  assert_output --partial "while"
  assert_output --partial "where"
}

@test "when a behaviour change is needed then the tree must exist before implementation starts" {
  run cat "$PROJECT_ROOT/skills/change/SKILL.md"
  assert_output --partial "Before implementation"
  assert_output --partial "Trees first, code second"
}

@test "when implementation reveals new understanding then the tree is updated to reflect reality" {
  run cat "$PROJECT_ROOT/skills/tdd/SKILL.md"
  assert_output --partial "Add its tree from the behaviour the consumer requires."
}
