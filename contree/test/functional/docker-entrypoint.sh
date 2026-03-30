#!/usr/bin/env bash
set -euo pipefail

# Runs a single functional test inside the Docker container.
# Called by docker-run.sh — not meant to be run directly.
#
# Expects:
#   - ANTHROPIC_API_KEY in environment
#   - /work/contree/ contains the plugin source
#   - /output/ is mounted for transcript output
#   - $1 is the test name (e.g. "incidental-pass")

TEST_NAME="${1:?Usage: docker-entrypoint.sh <test-name>}"
CONTREE_ROOT="/work/contree"
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
  (cd "$PROJECT_DIR" && claude -p "$prompt" \
    --plugin-dir "$CONTREE_ROOT" \
    --dangerously-skip-permissions \
    --model sonnet \
    --max-budget-usd 0.50 \
    --no-session-persistence \
    --output-format stream-json \
    --verbose \
    "$@" 2>&1) | tee "$TRANSCRIPT_FILE"
}

# --- Tests ---

case "$TEST_NAME" in
  incidental-pass)
    # Verifies: outside-in-tdd / when an expected-red test passes incidentally
    #
    # Seed project has reset() already implemented. TDD skill should write a
    # test that passes incidentally, then break the implementation, observe
    # failure, fix it, and observe pass.
    seed_project "$FIXTURES/incidental-pass"

    echo "Running: incidental-pass — TDD with pre-existing implementation"
    run_claude \
      "Use the tdd skill to implement the 'when reset after incrementing / then value is zero' path from the Counter test tree in ## Requirements. The reset() function already exists in counter.js — follow the TDD process exactly as described in the skill, including the incidental-pass protocol if the test passes on first run."
    ;;

  setup-generates-requirements)
    # Verifies: setup-generates-trees / when setup is run on an existing project
    #
    # Runs /setup on the seed project. Expects: test trees in CLAUDE.md,
    # vitest configured, tree reporters set up.
    seed_project "$FIXTURES/seed-project"

    echo "Running: setup-generates-requirements — /setup on existing project"
    run_claude \
      "Run /setup on this project. It's a simple JS counter module. Use Vitest. Don't implement any tests yet — just configure the framework and generate requirement trees."
    ;;

  tdd-writes-requirement-first)
    # Verifies: outside-in-tdd / when TDD discovers new test cases
    #
    # Seed project has counter with requirements for default/increment.
    # Asks to add reset — should extend the tree then TDD.
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
    ;;

  stop-hook-fires)
    # Verifies: stop-hook-sync / when Claude stops after any response
    #
    # Makes a code change and checks whether the stop hook prompted
    # CLAUDE.md updates.
    seed_project "$FIXTURES/seed-project"

    echo "Running: stop-hook-fires — stop hook prompts CLAUDE.md update"
    run_claude \
      "Add an 'amount' parameter to increment() so it can increment by more than 1. Update counter.js."
    ;;

  setup-docker-testing)
    # Verifies: setup-generates-trees / when the project needs external services for functional tests
    #
    # Seed project describes needing a database for functional tests.
    # Setup should generate Docker infrastructure for functional testing.
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
