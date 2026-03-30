#!/usr/bin/env bash
set -euo pipefail

# Runs a single functional test.
# Works both inside Docker (called by docker-run.sh) and directly on the host.
#
# Expects:
#   - ANTHROPIC_API_KEY in environment or in .env file
#   - $1 is the test name (e.g. "incidental-pass")

TEST_NAME="${1:?Usage: docker-entrypoint.sh <test-name>}"

# When running inside Docker, contree is at /work/contree.
# When running locally, derive from script location.
if [ -d "/work/contree" ]; then
  CONTREE_ROOT="/work/contree"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  CONTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Load .env if present (for local runs — API key for functional tests only)
ENV_FILE="$CONTREE_ROOT/test/functional/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi
FIXTURES="$CONTREE_ROOT/test/fixtures"
PROJECT_DIR="/tmp/contree-test-project"
TRANSCRIPT_FILE="/output/${TEST_NAME}-transcript.jsonl"

# --- Helpers ---

seed_project() {
  local fixture_dir="$1"
  rm -rf "$PROJECT_DIR"
  mkdir -p "$PROJECT_DIR"
  cp -r "$fixture_dir"/* "$PROJECT_DIR/"
  [ -f "$fixture_dir/CLAUDE.md" ] && cp "$fixture_dir/CLAUDE.md" "$PROJECT_DIR/"
  (cd "$PROJECT_DIR" && git init -q && git config user.email "test@test" && git config user.name "test" && git add -A && git commit -q -m "seed")
  (cd "$PROJECT_DIR" && npm install --silent 2>/dev/null)
}

run_claude() {
  local prompt="$1"
  shift
  # Don't abort on claude failure — we still need to emit VERIFY criteria
  (cd "$PROJECT_DIR" && claude -p "$prompt" \
    --plugin-dir "$CONTREE_ROOT" \
    --dangerously-skip-permissions \
    --model sonnet \
    --max-budget-usd 0.50 \
    --no-session-persistence \
    --output-format stream-json \
    --verbose \
    "$@" 2>&1) | tee "$TRANSCRIPT_FILE" || true
}

# --- Tests ---

case "$TEST_NAME" in
  incidental-pass)
    # Verifies: outside-in-tdd / when an expected-red test passes incidentally
    seed_project "$FIXTURES/incidental-pass"

    echo "Running: incidental-pass — TDD with pre-existing implementation"
    run_claude \
      "Use the tdd skill to implement the 'when reset after incrementing / then value is zero' path from the Counter test tree in ## Requirements. The reset() function already exists in counter.js — follow the TDD process exactly as described in the skill, including the incidental-pass protocol if the test passes on first run."

    cat << 'VERIFY'

=== VERIFY ===
1. Agent wrote a functional test for "when reset after incrementing / then value is zero"
2. Agent ran the test and it passed on first run (incidental pass)
3. Agent recognised the incidental pass and invoked the break/verify protocol
4. Agent broke the reset() implementation intentionally (e.g. commented out count = 0)
5. Agent ran the test and observed it failing
6. Agent fixed the implementation back to working state
7. Agent ran the test and observed it passing
VERIFY
    ;;

  setup-generates-requirements)
    # Verifies: setup-generates-trees / when setup is run on an existing project
    seed_project "$FIXTURES/seed-project"

    echo "Running: setup-generates-requirements — /setup on existing project"
    run_claude \
      "Run /setup on this project. It's a simple JS counter module. Use Vitest. Don't implement any tests yet — just configure the framework and generate requirement trees."

    cat << 'VERIFY'

=== VERIFY ===
1. Agent invoked the setup skill
2. Agent read the existing counter.js to understand the codebase
3. Agent configured vitest (vitest.config.* exists, vitest in package.json)
4. Agent configured tree reporters for human-readable nested output
5. Agent configured separate unit and functional test commands
6. Agent generated test trees in when/then format under ## Requirements in CLAUDE.md
7. Agent did NOT write any test implementations
VERIFY
    ;;

  tdd-writes-requirement-first)
    # Verifies: outside-in-tdd / when TDD discovers new test cases
    seed_project "$FIXTURES/seed-project"
    cat >> "$PROJECT_DIR/CLAUDE.md" << 'EOF'

## Requirements

### Counter

```
Counter
  when created with default
    then value is zero
  when incremented
    then value increases by one
```
EOF
    (cd "$PROJECT_DIR" && git add -A && git commit -q -m "add requirements")

    echo "Running: tdd-writes-requirement-first — add reset via TDD"
    run_claude \
      "Add a reset feature to the counter that sets it back to zero. Follow the tdd skill."

    cat << 'VERIFY'

=== VERIFY ===
1. Agent added a "when reset" path to the test tree in ## Requirements before writing code
2. Agent wrote a failing functional test for reset behaviour
3. Agent wrote a failing unit test for reset
4. Agent implemented reset() in counter.js
5. Agent confirmed unit test passes, then functional test passes
6. Tests follow outside-in order: functional first, then unit, then implement
VERIFY
    ;;

  stop-hook-fires)
    # Verifies: stop-hook-sync / when Claude stops after any response
    seed_project "$FIXTURES/seed-project"

    echo "Running: stop-hook-fires — stop hook prompts CLAUDE.md update"
    run_claude \
      "Add an 'amount' parameter to increment() so it can increment by more than 1. Update counter.js."

    cat << 'VERIFY'

=== VERIFY ===
1. Agent modified counter.js to add the amount parameter to increment()
2. Stop hook fired after the agent's response
3. Agent checked whether CLAUDE.md needs updating (drift detection)
4. Agent updated CLAUDE.md to reflect the new amount parameter (or asked the user about it)
VERIFY
    ;;

  setup-docker-testing)
    # Verifies: setup-generates-trees / when the project needs external services
    seed_project "$FIXTURES/seed-project"
    cat >> "$PROJECT_DIR/CLAUDE.md" << 'EOF'

## Mental Model

This project manages user accounts. It uses PostgreSQL for persistence.
Functional tests need a real database — no mocks.
EOF
    (cd "$PROJECT_DIR" && git add -A && git commit -q -m "describe external service needs")

    echo "Running: setup-docker-testing — /setup with external service dependency"
    run_claude \
      "Run /setup on this project. It's a user account service that needs PostgreSQL for functional tests. Use Vitest. Configure Docker-based functional testing with a real Postgres container. Don't implement any tests yet — just configure the framework, Docker infrastructure, and generate requirement trees."

    cat << 'VERIFY'

=== VERIFY ===
1. Agent invoked the setup skill
2. Agent created Docker infrastructure for functional tests (Dockerfile and/or docker-compose.yml)
3. Docker config includes a PostgreSQL service/container
4. Secrets/credentials are passed via environment variables, not hardcoded
5. Test artefacts (containers) are torn down after tests run (docker-compose down, --rm, or equivalent)
6. Agent configured vitest with tree reporters
7. Agent generated test trees under ## Requirements in CLAUDE.md
8. Agent did NOT write any test implementations
VERIFY
    ;;

  *)
    echo "Unknown test: $TEST_NAME" >&2
    echo ""
    echo "Available tests:"
    echo "  incidental-pass              — TDD incidental-pass protocol"
    echo "  setup-generates-requirements — /setup on existing project"
    echo "  tdd-writes-requirement-first — TDD discovers new test cases"
    echo "  stop-hook-fires              — stop hook prompts updates"
    echo "  setup-docker-testing         — /setup with Docker for external services"
    exit 1
    ;;
esac

echo ""
echo "Transcript saved to: $TRANSCRIPT_FILE"
