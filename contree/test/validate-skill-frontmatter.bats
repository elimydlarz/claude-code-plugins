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

@test "when every skills/*/SKILL.md has non-empty frontmatter name and description then the validator exits 0" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/alpha" "$(well_formed_body)"
  write_skill "$skills/beta" "$(well_formed_body)"

  run bash "$SCRIPT" "$skills"
  [ "$status" -eq 0 ] || return 1
  [ -z "$output" ] || return 1
}

@test "when every skills/*/SKILL.md has non-empty frontmatter name and description and this holds for contree's own real skills/ directory, not just synthetic fixtures" {
  run bash "$SCRIPT" "$PROJECT_ROOT/skills"
  [ "$status" -eq 0 ] || return 1
  [ -z "$output" ] || return 1
}

@test "when the skills directory has no SKILL.md files then the validator exits 0" {
  local skills="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$skills"

  run bash "$SCRIPT" "$skills"
  [ "$status" -eq 0 ] || return 1
  [ -z "$output" ] || return 1
}

@test "if a SKILL.md's frontmatter name is missing then the validator exits non-zero" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/good" "$(well_formed_body)"
  write_skill "$skills/bad" '---
description: "Has a description but no name."
---

# Bad
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ] || return 1
}

@test "if a SKILL.md's frontmatter name is missing and names the offending file" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/good" "$(well_formed_body)"
  write_skill "$skills/bad" '---
description: "Has a description but no name."
---

# Bad
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ] || return 1
  assert_output --partial "bad/SKILL.md"
}

@test "if a SKILL.md's frontmatter description is empty then the validator exits non-zero" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/bad" '---
name: bad
description: ""
---

# Bad
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ] || return 1
}

@test "if a SKILL.md's frontmatter description is empty and names the offending file" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/bad" '---
name: bad
description: ""
---

# Bad
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ] || return 1
  assert_output --partial "bad/SKILL.md"
}

@test "if a SKILL.md has no frontmatter at all then the validator exits non-zero" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/bad" '# No frontmatter here
just body.
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ] || return 1
  assert_output --partial "bad/SKILL.md"
  assert_output --partial "frontmatter"
}

@test "if a SKILL.md's frontmatter has no closing marker then the validator exits non-zero" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/bad" '---
name: bad
description: "Never closed"

# Body
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ] || return 1
  assert_output --partial "bad/SKILL.md"
  assert_output --partial "frontmatter"
}

@test "if a SKILL.md has content before its frontmatter then the validator exits non-zero and names the offending file" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/bad" 'body before frontmatter
---
name: bad
description: "Late metadata."
---
'

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ] || return 1
  assert_output --partial "bad/SKILL.md"
}

@test "if a SKILL.md's frontmatter name contains only whitespace then the validator exits non-zero and names the offending file" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/double-quoted" '---
name: "   "
description: "Has a description."
---
'
  write_skill "$skills/single-quoted" "---
name: '   '
description: 'Has a description.'
---
"

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ] || return 1
  assert_output --partial "double-quoted/SKILL.md"
  assert_output --partial "single-quoted/SKILL.md"
}

@test "if a SKILL.md's frontmatter description contains only whitespace then the validator exits non-zero and names the offending file" {
  local skills="$BATS_TEST_TMPDIR/skills"
  write_skill "$skills/double-quoted" '---
name: bad
description: "   "
---
'
  write_skill "$skills/single-quoted" "---
name: bad
description: '   '
---
"

  run bash "$SCRIPT" "$skills"
  [ "$status" -ne 0 ] || return 1
  assert_output --partial "double-quoted/SKILL.md"
  assert_output --partial "single-quoted/SKILL.md"
}

@test "if the skills directory does not exist then the validator exits non-zero" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -ne 0 ] || return 1
  assert_output --partial "does not exist"
}

@test "if no argument is given then the validator exits non-zero" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}
