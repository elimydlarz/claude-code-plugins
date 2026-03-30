#!/usr/bin/env bash
set -euo pipefail

# Analyse functional test transcripts.
# Uses the Anthropic API directly (via node) to avoid CLI plugin interference.
#
# Usage:
#   ./analyse.sh                     # analyse all transcripts
#   ./analyse.sh incidental-pass     # analyse one

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

[ -f "$SCRIPT_DIR/.env" ] && set -a && . "$SCRIPT_DIR/.env" && set +a

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "Error: ANTHROPIC_API_KEY must be set (in .env or environment)" >&2
  exit 1
fi

ALL_TESTS=(incidental-pass setup-generates-requirements tdd-writes-requirement-first stop-hook-fires setup-docker-testing)

criteria_for() {
  case "$1" in
    incidental-pass) echo '1. Agent wrote a functional test for "when reset after incrementing / then value is zero"
2. Agent ran the test and it passed on first run (incidental pass)
3. Agent recognised the incidental pass and invoked the break/verify protocol
4. Agent broke the reset() implementation intentionally (e.g. commented out count = 0)
5. Agent ran the test and observed it failing
6. Agent fixed the implementation back to working state
7. Agent ran the test and observed it passing' ;;
    setup-generates-requirements) echo '1. Agent invoked the setup skill
2. Agent read the existing counter.js to understand the codebase
3. Agent configured vitest (vitest.config.* exists, vitest in package.json)
4. Agent configured tree reporters for human-readable nested output
5. Agent configured separate unit and functional test commands
6. Agent generated test trees in when/then format under ## Requirements in CLAUDE.md
7. Agent did NOT write any test implementations' ;;
    tdd-writes-requirement-first) echo '1. Agent added a "when reset" path to the test tree in ## Requirements before writing code
2. Agent wrote a failing functional test for reset behaviour
3. Agent wrote a failing unit test for reset
4. Agent implemented reset() in counter.js
5. Agent confirmed unit test passes, then functional test passes
6. Tests follow outside-in order: functional first, then unit, then implement' ;;
    stop-hook-fires) echo '1. Agent modified counter.js to add the amount parameter to increment()
2. Stop hook fired after the agent'\''s response
3. Agent checked whether CLAUDE.md needs updating (drift detection)
4. Agent updated CLAUDE.md to reflect the new amount parameter (or asked the user about it)' ;;
    setup-docker-testing) echo '1. Agent invoked the setup skill
2. Agent created Docker infrastructure for functional tests (Dockerfile and/or docker-compose.yml)
3. Docker config includes a PostgreSQL service/container
4. Secrets/credentials are passed via environment variables, not hardcoded
5. Test artefacts (containers) are torn down after tests run (docker-compose down, --rm, or equivalent)
6. Agent configured vitest with tree reporters
7. Agent generated test trees under ## Requirements in CLAUDE.md
8. Agent did NOT write any test implementations' ;;
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

  local narrative criteria
  narrative="$(jq -r '
    select(.type == "assistant") |
    .message.content[]? // empty |
    if .type == "text" then "TEXT: " + .text
    elif .type == "tool_use" then "TOOL: " + .name + " — " + (.input | tostring | .[0:200])
    else empty end
  ' "$transcript" 2>/dev/null)"

  criteria="$(criteria_for "$test_name")"

  # Call Anthropic API directly — no CLI plugins
  local prompt
  prompt="Analyse this functional test transcript. For each numbered criterion, report PASS or FAIL with a one-line justification. End with a summary: X/Y PASS.

TRANSCRIPT:
$narrative

CRITERIA:
$criteria"

  # Escape for JSON
  local json_prompt
  json_prompt="$(printf '%s' "$prompt" | jq -Rs .)"

  local response
  response="$(curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "{
      \"model\": \"claude-haiku-4-5-20251001\",
      \"max_tokens\": 1024,
      \"messages\": [{\"role\": \"user\", \"content\": $json_prompt}]
    }")"

  echo "$response" | jq -r '.content[0].text // .error.message // "Error: unexpected response"'
}

TEST_NAME="${1:-all}"

if [ "$TEST_NAME" = "all" ]; then
  for t in "${ALL_TESTS[@]}"; do analyse_one "$t"; done
else
  analyse_one "$TEST_NAME"
fi
