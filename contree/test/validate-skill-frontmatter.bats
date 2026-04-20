#!/usr/bin/env bats

load test_helper

SCRIPT="$PROJECT_ROOT/scripts/validate-skill-frontmatter.sh"

write_skill() {
  local dir="$1"
  local body="$2"
  mkdir -p "$dir"
  printf '%s' "$body" > "$dir/SKILL.md"
}

well_formed_body() {
  cat <<'EOF'
---
name: example
description: "Does the thing."
---

# Example
EOF
}

@test "exits 0 when every SKILL.md has non-empty name and description" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/alpha" "$(well_formed_body)"
  write_skill "$skills/beta" "$(well_formed_body)"

  run bash "$SCRIPT" "$skills"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 when skills dir has no SKILL.md" {
  local skills="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$skills"

  run bash "$SCRIPT" "$skills"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits non-zero and names the offender when name is missing" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/good" "$(well_formed_body)"
  write_skill "$skills/bad" '---
description: "Has a description but no name."
---

# Bad
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bad/SKILL.md"* ]]
  [[ "$output" == *"name"* ]]
}

@test "exits non-zero and names the offender when description is empty" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/bad" '---
name: bad
description: ""
---

# Bad
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bad/SKILL.md"* ]]
  [[ "$output" == *"description"* ]]
}

@test "exits non-zero when frontmatter is missing entirely" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/bad" '# No frontmatter here
just body.
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bad/SKILL.md"* ]]
  [[ "$output" == *"frontmatter"* ]]
}

@test "exits non-zero when frontmatter has no closing marker" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/bad" '---
name: bad
description: "Never closed"

# Body
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bad/SKILL.md"* ]]
  [[ "$output" == *"frontmatter"* ]]
}

@test "exits non-zero when the skills dir does not exist" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "exits non-zero when no argument is given" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "passes for the real contree skills dir" {
  run bash "$SCRIPT" "$PROJECT_ROOT/skills"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
