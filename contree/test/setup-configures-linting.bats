#!/usr/bin/env bats

load test_helper

SKILL="$PROJECT_ROOT/skills/setup/SKILL.md"

extract_js_lint_hook() {
  local target="$1"
  sed -n '/^JS\/TS:$/,/^```$/p' "$SKILL" | sed '1,3d;$d' > "$target"
  chmod +x "$target"
}

create_js_hook_project() {
  local project="$1"
  mkdir -p "$project/bin"
  git -C "$project" init -q
  extract_js_lint_hook "$project/lint-on-save.sh"
}

@test "setup configures a normal linter" {
  run cat "$SKILL"
  assert_output --partial "normal linter"
  assert_output --partial "project's language conventions"
}

@test "when setup is run then a conventional normal linter is installed and configured with the ecosystem's strong recommended rules" {
  run cat "$SKILL"
  assert_output --partial "@eslint/js"
  assert_output --partial "strictTypeChecked"
  assert_output --partial "credo --strict"
  assert_output --partial "golangci-lint run"
}

@test "when setup is run then a project-level hook is created for coding-agent file saves" {
  run cat "$SKILL"
  assert_output --partial ".claude/settings.json"
  assert_output --partial ".codex/hooks.json"
  assert_output --partial "PostToolUse"
  assert_output --partial '"matcher": "Edit|Write"'
  assert_output --partial "Merge into existing project hook configuration"
}

@test "when a coding agent writes or edits a project file then the project-level hook runs the normal lint autofix command from the project root after every save" {
  run cat "$SKILL"
  assert_output --partial ".contree/hooks/lint-on-save.sh"
  assert_output --partial "pnpm lint:code:fix"
  assert_output --partial "mix format"
  assert_output --partial "mix credo --strict"
  assert_output --partial "golangci-lint run --fix"
  assert_output --partial "from the project root"
}

@test "when a coding agent writes or edits a project file then automatic fixes are written to the file before the coding agent continues" {
  run cat "$SKILL"
  assert_output --partial "synchronous PostToolUse command"
  assert_output --partial "before the coding agent continues"
  refute_output --partial '"async": true'

  local project="$BATS_TEST_TMPDIR/autofix-project"
  create_js_hook_project "$project"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "const fixed = true" > saved.js' > "$project/bin/pnpm"
  chmod +x "$project/bin/pnpm"
  printf '%s\n' 'const  broken=true' > "$project/saved.js"

  cd "$project"
  run env PATH="$project/bin:$PATH" bash "$project/lint-on-save.sh"

  assert_success
  run cat "$project/saved.js"
  assert_output "const fixed = true"
}

@test "if lint violations remain after automatic fixes then the project-level hook reports the violations and fails visibly" {
  run cat "$SKILL"
  assert_output --partial "remaining lint violations"
  assert_output --partial "write the linter output to stderr"
  assert_output --partial 'if output=$(pnpm lint:code:fix 2>&1); then'
  assert_output --partial "printf '%s\\n' \"\$output\" >&2"
  assert_output --partial "exit 2"

  local project="$BATS_TEST_TMPDIR/failing-project"
  create_js_hook_project "$project"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "saved.js:1:1 unfixable lint violation" >&2' 'exit 1' > "$project/bin/pnpm"
  chmod +x "$project/bin/pnpm"

  cd "$project"
  run env PATH="$project/bin:$PATH" bash "$project/lint-on-save.sh"

  assert_equal "$status" 2
  assert_output --partial "saved.js:1:1 unfixable lint violation"
}

@test "setup configures a hex-boundary linter" {
  run cat "$SKILL"
  [[ "$output" == *"dependency-cruiser"* || "$output" == *"hex-boundary"* || "$output" == *"architectural linter"* ]]
}

@test "when setup is run then an architecture linter is installed and configured for every project source layout" {
  run cat "$SKILL"
  assert_output --partial "dependency-cruiser"
  assert_output --partial "(^|/)domain/"
  assert_output --partial "(^|/)(application|use-cases?)/"
  assert_output --partial "(^|/)(adapters?|infrastructure)/"
  refute_output --partial "src/.+/domain/"
}

@test "setup configures one combined lint command" {
  run cat "$SKILL"
  assert_output --partial "combined lint command"
  assert_output --partial "normal lint"
  assert_output --partial "hex-boundary lint"
}

@test "setup configures the hex-boundary linter to enforce Domain has no I/O" {
  run cat "$SKILL"
  assert_output --partial "Domain"
  assert_output --regexp 'no I/O|not reach adapters'
}

@test "setup configures the hex-boundary linter to enforce use-cases depend on ports, not concrete adapters" {
  run cat "$SKILL"
  assert_output --partial "ports"
  assert_output --regexp 'not concrete adapters|interfaces'
}

@test "setup configures the hex-boundary linter to enforce no circular dependencies" {
  run cat "$SKILL"
  assert_output --partial "no-circular"
  assert_output --partial "circular: true"
}

@test "setup wires CI to run the combined lint command so normal and boundary violations fail the build" {
  run cat "$SKILL"
  assert_output --partial "Ensure CI runs"
  assert_output --partial "normal and boundary violations fail the build"
}

@test "setup names the language-native equivalent tool and states the rules to enforce when no first-party template exists" {
  run cat "$SKILL"
  assert_output --partial "For non-JS/TS hex-boundary lint"
  assert_output --partial "recommend the language-native equivalent"
  assert_output --partial "ArchUnit"
  assert_output --partial "depguard"
  assert_output --partial "import-linter"
  assert_output --partial "cargo-modules"
}

@test "setup communicates honestly that the user wires the rules themselves without a first-party template" {
  run cat "$SKILL"
  assert_output --partial "State the limitation honestly"
  assert_output --partial "the user wires the rules themselves"
}
