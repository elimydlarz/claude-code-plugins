#!/usr/bin/env bash
set -euo pipefail

# Analyse functional test transcripts.
# Feeds each transcript + VERIFY criteria into claude -p (haiku) and collects verdicts.
#
# Usage:
#   ./analyse.sh                     # analyse all transcripts
#   ./analyse.sh incidental-pass     # analyse one

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ALL_TESTS=(incidental-pass setup-generates-requirements tdd-writes-requirement-first stop-hook-fires setup-docker-testing)

# --- Criteria per test ---

criteria_for() {
  case "$1" in
    incidental-pass) cat << 'EOF'
1. Agent wrote a functional test for "when reset after incrementing / then value is zero"
2. Agent ran the test and it passed on first run (incidental pass)
3. Agent recognised the incidental pass and invoked the break/verify protocol
4. Agent broke the reset() implementation intentionally (e.g. commented out count = 0)
5. Agent ran the test and observed it failing
6. Agent fixed the implementation back to working state
7. Agent ran the test and observed it passing
EOF
      ;;
    setup-generates-requirements) cat << 'EOF'
1. Agent invoked the setup skill
2. Agent read the existing counter.js to understand the codebase
3. Agent configured vitest (vitest.config.* exists, vitest in package.json)
4. Agent configured tree reporters for human-readable nested output
5. Agent configured separate unit and functional test commands
6. Agent generated test trees in when/then format under ## Requirements in CLAUDE.md
7. Agent did NOT write any test implementations
EOF
      ;;
    tdd-writes-requirement-first) cat << 'EOF'
1. Agent added a "when reset" path to the test tree in ## Requirements before writing code
2. Agent wrote a failing functional test for reset behaviour
3. Agent wrote a failing unit test for reset
4. Agent implemented reset() in counter.js
5. Agent confirmed unit test passes, then functional test passes
6. Tests follow outside-in order: functional first, then unit, then implement
EOF
      ;;
    stop-hook-fires) cat << 'EOF'
1. Agent modified counter.js to add the amount parameter to increment()
2. Stop hook fired after the agent's response
3. Agent checked whether CLAUDE.md needs updating (drift detection)
4. Agent updated CLAUDE.md to reflect the new amount parameter (or asked the user about it)
EOF
      ;;
    setup-docker-testing) cat << 'EOF'
1. Agent invoked the setup skill
2. Agent created Docker infrastructure for functional tests (Dockerfile and/or docker-compose.yml)
3. Docker config includes a PostgreSQL service/container
4. Secrets/credentials are passed via environment variables, not hardcoded
5. Test artefacts (containers) are torn down after tests run (docker-compose down, --rm, or equivalent)
6. Agent configured vitest with tree reporters
7. Agent generated test trees under ## Requirements in CLAUDE.md
8. Agent did NOT write any test implementations
EOF
      ;;
    *) echo "Unknown test: $1" >&2; return 1 ;;
  esac
}

analyse_one() {
  local test_name="$1"
  local transcript="$SCRIPT_DIR/${test_name}-transcript.jsonl"

  if [ ! -f "$transcript" ]; then
    echo "=== $test_name: SKIP (no transcript) ==="
    return
  fi

  echo ""
  echo "=== Analysing: $test_name ==="

  local narrative criteria prompt_file verdict
  narrative="$(jq -r '
    select(.type == "assistant") |
    .message.content[]? // empty |
    if .type == "text" then "TEXT: " + .text
    elif .type == "tool_use" then "TOOL: " + .name + " — " + (.input | tostring | .[0:200])
    else empty end
  ' "$transcript" 2>/dev/null)"

  criteria="$(criteria_for "$test_name")"

  prompt_file="$(mktemp)"
  cat > "$prompt_file" << EOF
You are analysing a functional test transcript. For each criterion, report PASS or FAIL with a one-line justification. End with a summary line: "X/Y PASS".

## Transcript

$narrative

## Criteria

$criteria
EOF

  verdict="$(env -u ANTHROPIC_API_KEY claude -p "$(cat "$prompt_file")" \
    --model haiku \
    --max-budget-usd 0.25 \
    --no-session-persistence \
    --system-prompt 'You are a test transcript analyser. Respond only with PASS/FAIL verdicts.' \
    2>/dev/null)" || true
  rm -f "$prompt_file"

  echo "$verdict"
}

TEST_NAME="${1:-all}"

if [ "$TEST_NAME" = "all" ]; then
  for t in "${ALL_TESTS[@]}"; do analyse_one "$t"; done
else
  analyse_one "$TEST_NAME"
fi
