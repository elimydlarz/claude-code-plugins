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

extract_architecture_stop_hook() {
  local target="$1"
  awk '
    /Create executable `.contree\/hooks\/architecture-on-stop.sh`/ { found = 1; next }
    found && /^```bash$/ { body = 1; next }
    body && /^```$/ { exit }
    body { print }
  ' "$SKILL" > "$target"
  chmod +x "$target"
}

create_architecture_hook_project() {
  local project="$1"
  mkdir -p "$project/bin"
  git -C "$project" init -q
  extract_architecture_stop_hook "$project/architecture-on-stop.sh"
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

@test "when setup is run then a project-level Stop hook is merged with the project's existing hooks" {
  run cat "$SKILL"
  assert_output --partial 'Add the same Stop matcher group to `.claude/settings.json` and `.codex/hooks.json`'
  assert_output --partial '"Stop"'
  assert_output --partial ".contree/hooks/architecture-on-stop.sh"
  assert_output --partial "Merge the Stop matcher group without replacing existing settings or hooks"
}

@test "when a coding agent Stop task runs then the project-level Stop hook runs every architecture rule from the project root" {
  run cat "$SKILL"
  assert_output --partial 'Create executable `.contree/hooks/architecture-on-stop.sh`'
  assert_output --partial 'Create executable `.contree/scripts/lint-architecture.sh`'
  assert_output --partial 'cd "$(git rev-parse --show-toplevel)"'
  assert_output --partial "pnpm lint:arch"
  assert_output --partial "pnpm exec eslint"
  assert_output --partial "pnpm exec depcruise"
  assert_output --partial "--output-type err-long"
  assert_output --partial '"lint:arch": "bash .contree/scripts/lint-architecture.sh"'
  refute_output --partial '"lint:arch": "depcruise'
}

@test "if architecture violations are found during a Stop task then the project-level Stop hook reports every violation with its rule, source, and forbidden dependency and the Stop task fails" {
  local project="$BATS_TEST_TMPDIR/architecture-violations"
  create_architecture_hook_project "$project"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "error domain-pure: src/domain/order.ts -> node:fs" >&2' 'printf "%s\n" "error no-circular: src/a.ts -> src/b.ts -> src/a.ts" >&2' 'exit 1' > "$project/bin/pnpm"
  chmod +x "$project/bin/pnpm"

  cd "$project"
  run env PATH="$project/bin:$PATH" bash -c 'printf "%s" "{\"stop_hook_active\":false}" | bash "$1"' _ "$project/architecture-on-stop.sh"

  assert_equal "$status" 2
  assert_output --partial "error domain-pure: src/domain/order.ts -> node:fs"
  assert_output --partial "error no-circular: src/a.ts -> src/b.ts -> src/a.ts"
}

@test "if the architecture linter cannot run during a Stop task then the project-level Stop hook reports the execution error and the Stop task fails" {
  local project="$BATS_TEST_TMPDIR/architecture-execution-error"
  create_architecture_hook_project "$project"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "dependency-cruiser executable is unavailable" >&2' 'exit 127' > "$project/bin/pnpm"
  chmod +x "$project/bin/pnpm"

  cd "$project"
  run env PATH="$project/bin:$PATH" bash -c 'printf "%s" "{\"stop_hook_active\":false}" | bash "$1"' _ "$project/architecture-on-stop.sh"

  assert_equal "$status" 2
  assert_output --partial "dependency-cruiser executable is unavailable"
}

@test "if every architecture rule passes during a Stop task then the project-level Stop hook exits successfully without architecture feedback" {
  local project="$BATS_TEST_TMPDIR/architecture-success"
  create_architecture_hook_project "$project"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$project/bin/pnpm"
  chmod +x "$project/bin/pnpm"

  cd "$project"
  run env PATH="$project/bin:$PATH" bash -c 'printf "%s" "{\"stop_hook_active\":false}" | bash "$1"' _ "$project/architecture-on-stop.sh"

  assert_success
  assert_output "{}"
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

@test "when setup is run then the architecture linter rejects domain dependencies on frameworks, I/O, asynchronous work, application code, and adapters" {
  run cat "$SKILL"
  assert_output --partial "domain-no-external-dependencies"
  assert_output --partial "'core', 'npm', 'npm-dev', 'npm-optional', 'npm-peer', 'npm-bundled', 'npm-no-pkg', 'npm-unknown'"
  assert_output --partial "domain-no-async"
  assert_output --partial "[async=true]"
  assert_output --partial "(^|/)(application|use-cases?|adapters?|infrastructure)/"
}

@test "setup configures the hex-boundary linter to enforce use-cases depend on ports, not concrete adapters" {
  run cat "$SKILL"
  assert_output --partial "ports"
  assert_output --regexp 'not concrete adapters|interfaces'
}

@test "when setup is run then the architecture linter restricts use-cases to domain code, plain data, and ports rather than frameworks, I/O, or concrete adapters" {
  run sed -n "/name: 'use-case-no-external-dependencies'/,/^    },/p" "$SKILL"
  assert_output --partial "from: { path: '(^|/)(application|use-cases?)/' }"
  assert_output --partial "dependencyTypes: ['core', 'npm', 'npm-dev', 'npm-optional', 'npm-peer', 'npm-bundled', 'npm-no-pkg', 'npm-unknown']"
  run sed -n "/name: 'use-case-only-domain-data-and-ports'/,/^    },/p" "$SKILL"
  assert_output --partial "dependencyTypes: ['local', 'localmodule']"
  assert_output --partial "domain|ports?|data|types"
}

@test "when setup is run then the architecture linter permits concrete adapters to be imported only by the composition root" {
  run sed -n "/name: 'adapters-only-from-composition-root'/,/^    },/p" "$SKILL"
  assert_output --partial "pathNot: '^src/composition-root"
  assert_output --partial "to: { path: '(^|/)(adapters?|infrastructure)/' }"
  run cat "$SKILL"
  assert_output --partial "replace the example composition-root path with the exact project path"
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

@test "if the project's ecosystem cannot enforce every architecture rule then setup fails visibly without claiming that the project is prepared" {
  run cat "$SKILL"
  assert_output --partial "If the project's ecosystem cannot enforce every architecture rule, fail setup visibly"
  assert_output --partial "Do not claim that the project is prepared"
  refute_output --partial "the user wires the rules themselves"
}
