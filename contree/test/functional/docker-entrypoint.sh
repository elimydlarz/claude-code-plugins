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
# Transcripts go next to this script (host) or /output (Docker)
OUTPUT_DIR="$CONTREE_ROOT/test/functional"
if [ -d "/output" ]; then
  OUTPUT_DIR="/output"
fi
TRANSCRIPT_FILE="$OUTPUT_DIR/${TEST_NAME}-transcript.jsonl"
VERIFY_FILE="$OUTPUT_DIR/${TEST_NAME}-verify.txt"

# --- Helpers ---

seed_project() {
  local fixture_name="$1"
  # Use pre-installed fixtures from Docker image if available, otherwise from plugin source
  local fixture_dir="/fixtures/$fixture_name"
  [ -d "$fixture_dir" ] || fixture_dir="$FIXTURES/$fixture_name"

  rm -rf "$PROJECT_DIR"
  cp -r "$fixture_dir" "$PROJECT_DIR"
  [ -f "$FIXTURES/$fixture_name/CLAUDE.md" ] && cp "$FIXTURES/$fixture_name/CLAUDE.md" "$PROJECT_DIR/"
  (cd "$PROJECT_DIR" && git init -q && git config user.email "test@test" && git config user.name "test" && git add -A && git commit -q -m "seed")
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

# Run claude interactively via tmux so UserPromptSubmit hooks fire.
# Captures plain-text output to TRANSCRIPT_FILE.
run_claude_interactive() {
  local prompt="$1"
  local session="contree-$$"

  # Write a wrapper that sets env and launches claude
  local wrapper
  wrapper=$(mktemp /tmp/claude-wrapper-XXXXXX.sh)
  cat > "$wrapper" << WRAPPER
#!/usr/bin/env bash
cd '$PROJECT_DIR'
export ANTHROPIC_API_KEY='${ANTHROPIC_API_KEY}'
export CONTREE_NUDGE_DIR='${CONTREE_NUDGE_DIR:-}'
claude --plugin-dir '$CONTREE_ROOT' \
  --dangerously-skip-permissions \
  --model sonnet \
  --max-budget-usd 0.50 \
  2>&1
WRAPPER
  chmod +x "$wrapper"

  tmux new-session -d -s "$session" "bash '$wrapper'"

  # Navigate through first-run setup wizards by watching the pane and sending keystrokes.
  # Each wizard is handled in order; we keep looping until the main prompt appears.
  local i=0
  while [ $i -lt 90 ]; do
    sleep 1; (( i++ )) || true
    local pane
    pane=$(tmux capture-pane -p -t "$session" 2>/dev/null)
    # Login method wizard: press Down to select "Anthropic Console account" then Enter
    if echo "$pane" | grep -q "Select login method"; then
      tmux send-keys -t "$session" Down Enter; sleep 1; continue
    fi
    # API key wizard: press Up to select "Yes" then Enter
    if echo "$pane" | grep -q "Detected a custom API key"; then
      tmux send-keys -t "$session" Up Enter; sleep 1; continue
    fi
    # Theme wizard: press Enter to accept default (Dark mode)
    if echo "$pane" | grep -q "Choose the text style"; then
      tmux send-keys -t "$session" "" Enter; sleep 1; continue
    fi
    # Ready for input when the main prompt line appears
    echo "$pane" | grep -q "^>" && break
  done

  # Send the prompt
  tmux send-keys -t "$session" "$prompt" Enter

  # Wait for response to settle: poll until output stops changing for 3s
  local prev="" rounds=0
  while [ $rounds -lt 60 ]; do
    sleep 3
    local curr
    curr=$(tmux capture-pane -p -t "$session" 2>/dev/null)
    [ "$curr" = "$prev" ] && break
    prev="$curr"
    (( rounds++ )) || true
  done

  # Save full captured output as transcript
  tmux capture-pane -p -t "$session" > "$TRANSCRIPT_FILE" 2>/dev/null || true
  tmux kill-session -t "$session" 2>/dev/null || true
  rm -f "$wrapper"
}

write_verify() {
  cat > "$VERIFY_FILE"
  echo ""
  cat "$VERIFY_FILE"
}

# --- Tests ---

case "$TEST_NAME" in
  incidental-pass)
    # Verifies: outside-in-tdd / when an expected-red test passes incidentally
    seed_project "incidental-pass"

    echo "Running: incidental-pass — TDD with pre-existing implementation"
    run_claude \
      "Use the tdd skill to implement the 'when reset after incrementing / then value is zero' path from the Counter test tree in ## Requirements. The reset() function already exists in counter.js — follow the TDD process exactly as described in the skill, including the incidental-pass protocol if the test passes on first run."

    write_verify << 'VERIFY'

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
    seed_project "seed-project"

    echo "Running: setup-generates-requirements — /setup on existing project"
    run_claude \
      "Run /setup on this project. It's a simple JS counter module. Use Vitest. Don't implement any tests yet — just configure the framework and generate requirement trees."

    write_verify << 'VERIFY'

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
    # Verifies: organic discovery — user describes adding + implementing a feature,
    # agent discovers it needs /change (requirements first) then /tdd (implement)
    seed_project "seed-project"
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

    echo "Running: tdd-writes-requirement-first — organic discovery of change then TDD"
    run_claude \
      "I want to add a reset feature to this counter that sets the value back to zero. Add it to the requirements and then implement it."

    write_verify << 'VERIFY'

=== VERIFY ===
1. Agent organically invoked a skill that writes requirements first (change, or workflow which runs change internally)
2. Agent added a "when reset" path to the test tree in ## Requirements before writing any code
3. Agent wrote a failing test for reset behaviour
4. Agent implemented reset() in counter.js
5. Agent confirmed tests pass
VERIFY
    ;;

  stop-hook-fires)
    # Verifies: stop-hook-sync / when Claude stops after any response
    seed_project "seed-project"

    echo "Running: stop-hook-fires — stop hook prompts CLAUDE.md update"
    run_claude \
      "Add an 'amount' parameter to increment() so it can increment by more than 1. Update counter.js."

    write_verify << 'VERIFY'

=== VERIFY ===
1. Agent modified counter.js to add the amount parameter to increment()
2. Agent performed drift detection (read CLAUDE.md, checked for staleness)
3. Agent identified that the Mental Model needs updating to reflect the amount parameter
4. Agent asked the user before modifying CLAUDE.md (never modifies silently)
VERIFY
    ;;

  setup-docker-testing)
    # Verifies: setup-generates-trees / when the project needs external services
    seed_project "seed-project"
    cat >> "$PROJECT_DIR/CLAUDE.md" << 'EOF'

## Mental Model

This project manages user accounts. It uses PostgreSQL for persistence.
Functional tests need a real database — no mocks.
EOF
    (cd "$PROJECT_DIR" && git add -A && git commit -q -m "describe external service needs")

    echo "Running: setup-docker-testing — /setup with external service dependency"
    run_claude \
      "Run /setup on this project. It's a user account service that needs PostgreSQL for functional tests. Use Vitest. Configure Docker-based functional testing with a real Postgres container. Do NOT write any test files — no .test.js, no .test.ts, no spec files. Only configuration and requirement trees."

    write_verify << 'VERIFY'

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

  discover-change)
    # Verifies: skill discoverability — natural prompt triggers change skill
    seed_project "seed-project"
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

    echo "Running: discover-change — natural prompt triggers change skill"
    run_claude \
      "I want to add a reset feature to this counter that sets the value back to zero. Let's figure out what the behaviour should look like before writing any code."

    write_verify << 'VERIFY'

=== VERIFY ===
1. Agent invoked the change skill (not tdd, not setup, not workflow)
2. Agent discussed the reset behaviour before modifying trees
3. Agent wrote or proposed when/then paths for reset in ## Requirements
4. Agent did NOT write any implementation code
VERIFY
    ;;

  discover-change-implicit)
    # Verifies: skill discoverability — bare feature request (no skill cues) triggers change skill
    seed_project "seed-project"
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

    echo "Running: discover-change-implicit — bare feature request triggers change skill"
    run_claude \
      "Add a decrement feature to the counter."

    write_verify << 'VERIFY'

=== VERIFY ===
1. Agent invoked the change skill before writing any code
2. Agent wrote or proposed when/then paths for decrement in ## Requirements
3. Agent did NOT write implementation code before the tree existed
VERIFY
    ;;

  discover-sync)
    # Verifies: skill discoverability — natural prompt triggers sync skill
    seed_project "sync-drift"

    echo "Running: discover-sync — natural prompt triggers sync skill"
    run_claude \
      "I've been making changes to counter.js and I'm not sure the requirements still match the code. Can you check what's drifted?"

    write_verify << 'VERIFY'

=== VERIFY ===
1. Agent invoked the sync skill (not change, not tdd)
2. Agent identified that decrement tree exists without implementation
3. Agent identified that amount parameter exists without a tree
4. Agent reported drift to the user rather than silently fixing it
VERIFY
    ;;

  discover-setup)
    # Verifies: skill discoverability — natural prompt triggers setup skill
    seed_project "seed-project"

    echo "Running: discover-setup — natural prompt triggers setup skill"
    run_claude \
      "This project doesn't have any testing set up yet. Can you get it ready for test-driven development? Use Vitest."

    write_verify << 'VERIFY'

=== VERIFY ===
1. Agent invoked the setup skill (not change, not tdd)
2. Agent configured vitest
3. Agent generated test trees under ## Requirements in CLAUDE.md
4. Agent did NOT write any test implementations
VERIFY
    ;;

  discover-tdd)
    # Verifies: skill discoverability — natural prompt triggers tdd skill
    seed_project "tdd-ready"

    echo "Running: discover-tdd — natural prompt triggers tdd skill"
    run_claude \
      "The requirements are all set — can you implement the increment behaviour from the test tree?"

    write_verify << 'VERIFY'

=== VERIFY ===
1. Agent invoked the tdd skill (not change, not setup)
2. Agent started with a failing test matching a when/then path
3. Agent wrote implementation code to make the test pass
VERIFY
    ;;

  ears-change)
    # Verifies: change-writes-trees / EARS patterns are chosen to match each requirement's nature
    seed_project "ears-project"

    echo "Running: ears-change — change skill writes requirements using varied EARS patterns"
    run_claude \
      "I want to define the requirements for this media player before writing any tests or code. It has states (playing, paused, stopped), events (load, pause, resume, stop), error handling (unsupported file formats), and an optional bluetooth feature. Define the requirements using the appropriate EARS patterns for each kind of requirement."

    write_verify << 'VERIFY'

=== VERIFY ===
1. Agent invoked the change skill
2. Trees written under ## Requirements in CLAUDE.md
3. At least one state-driven requirement using 'while' (e.g. while playing, while paused)
4. At least one event-driven requirement using 'when' (e.g. when a track is loaded)
5. At least one unwanted-behaviour requirement using 'if/then' (e.g. if the file format is unsupported)
6. Requirements use consumer vocabulary, not implementation details
VERIFY
    ;;

  no-tautologies)
    # Verifies: change-writes-trees / every then clause asserts something the when clause does not already imply
    seed_project "seed-project"

    echo "Running: no-tautologies — change skill rejects tautological then clauses"
    run_claude \
      "Use the change skill to write requirements for this counter module. It can be created with a default or custom initial value, incremented, decremented, and its value read. Write the test trees under ## Requirements in CLAUDE.md. Do NOT write any code or tests."

    write_verify << 'VERIFY'

=== VERIFY ===
1. Agent invoked the change skill
2. Agent wrote test trees under ## Requirements in CLAUDE.md
3. No then clause merely restates its when/while condition (e.g. "when created / then it is created" or "when incremented / then it increments")
4. Every then clause asserts a concrete, observable outcome (e.g. "when created with default / then value is zero")
5. Agent did NOT write any implementation code or tests
VERIFY
    ;;

  self-care-nudge)
    # Verifies: self-care-20-20-20 / when 20 minutes have elapsed since the most recent nudge file
    # Uses tmux interactive mode because UserPromptSubmit hooks don't fire in -p mode.
    seed_project "seed-project"

    # Pre-seed a nudge file timestamped 25 minutes ago so the hook fires on the first prompt.
    # Use a temp dir via CONTREE_NUDGE_DIR to avoid touching real nudge state.
    NUDGE_TMPDIR="$(mktemp -d)"
    NUDGE_DIR="$NUDGE_TMPDIR/20-20-20"
    mkdir -p "$NUDGE_DIR"
    touch "$NUDGE_DIR/$(( $(date +%s) - 1500 ))"
    export CONTREE_NUDGE_DIR="$NUDGE_DIR"

    echo "Running: self-care-nudge — UserPromptSubmit hook emits 20-20-20 reminder"
    run_claude_interactive "What does this counter module do?"

    rm -rf "$NUDGE_TMPDIR"
    unset CONTREE_NUDGE_DIR NUDGE_TMPDIR NUDGE_DIR

    write_verify << 'VERIFY'

=== VERIFY ===
1. Claude's response begins with (or very prominently includes) a 20-20-20 eye break reminder
2. The reminder mentions looking 20 feet away for 20 seconds
3. Claude also answers the question about the counter module
VERIFY
    ;;

  pressure-injection)
    # Verifies: pressure-injection / hook injects a phrase from phrases.txt before tool calls
    seed_project "seed-project"

    echo "Running: pressure-injection — PreToolUse hook injects pressure phrases"
    PRESSURE_ON=1 run_claude "What does this counter module do? Read the source file and explain it."

    write_verify << 'VERIFY'

=== VERIFY ===
1. Claude read the counter module source file (used a tool to read counter.js or similar)
2. At least one PreToolUse hook message appears in the transcript — look for a motivational or pressure phrase (e.g. mentions 'tip', 'boss', 'career', 'count on you', 'watching', 'depends', 'production', or similar urgency/stakes language)
3. Claude still completed the task and described what the counter module does
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
    echo "  discover-change              — natural prompt triggers change skill"
    echo "  discover-change-implicit     — bare feature request triggers change skill"
    echo "  discover-sync                — natural prompt triggers sync skill"
    echo "  discover-setup               — natural prompt triggers setup skill"
    echo "  discover-tdd                 — natural prompt triggers tdd skill"
    echo "  ears-change                  — change skill uses EARS patterns"
    echo "  no-tautologies               — change skill rejects tautological trees"
    echo "  self-care-nudge              — UserPromptSubmit hook fires 20-20-20 reminder"
    echo "  pressure-injection           — PreToolUse hook injects pressure phrases"
    exit 1
    ;;
esac

echo ""
echo "Transcript: $TRANSCRIPT_FILE"
echo "Verify:     $VERIFY_FILE"
