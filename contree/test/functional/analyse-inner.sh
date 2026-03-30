#!/usr/bin/env bash
set -euo pipefail

# Runs inside Docker. Analyses a single transcript against its criteria.
# Called by analyse.sh — not meant to be run directly.

TEST_NAME="${1:?Usage: analyse-inner.sh <test-name>}"
TRANSCRIPT="/transcripts/${TEST_NAME}-transcript.jsonl"

if [ ! -f "$TRANSCRIPT" ]; then
  echo "No transcript: $TRANSCRIPT"
  exit 1
fi

# --- Criteria per test ---

case "$TEST_NAME" in
  incidental-pass) CRITERIA='1. Agent wrote a functional test for "when reset after incrementing / then value is zero"
2. Agent ran the test and it passed on first run (incidental pass)
3. Agent recognised the incidental pass and invoked the break/verify protocol
4. Agent broke the reset() implementation intentionally (e.g. commented out count = 0)
5. Agent ran the test and observed it failing
6. Agent fixed the implementation back to working state
7. Agent ran the test and observed it passing' ;;

  setup-generates-requirements) CRITERIA='1. Agent invoked the setup skill
2. Agent read the existing counter.js to understand the codebase
3. Agent configured vitest (vitest.config.* exists, vitest in package.json)
4. Agent configured tree reporters for human-readable nested output
5. Agent configured separate unit and functional test commands
6. Agent generated test trees in when/then format under ## Requirements in CLAUDE.md
7. Agent did NOT write any test implementations' ;;

  tdd-writes-requirement-first) CRITERIA='1. Agent added a "when reset" path to the test tree in ## Requirements before writing code
2. Agent wrote a failing functional test for reset behaviour
3. Agent wrote a failing unit test for reset
4. Agent implemented reset() in counter.js
5. Agent confirmed unit test passes, then functional test passes
6. Tests follow outside-in order: functional first, then unit, then implement' ;;

  stop-hook-fires) CRITERIA='1. Agent modified counter.js to add the amount parameter to increment()
2. Stop hook fired after the agent'"'"'s response
3. Agent checked whether CLAUDE.md needs updating (drift detection)
4. Agent updated CLAUDE.md to reflect the new amount parameter (or asked the user about it)' ;;

  setup-docker-testing) CRITERIA='1. Agent invoked the setup skill
2. Agent created Docker infrastructure for functional tests (Dockerfile and/or docker-compose.yml)
3. Docker config includes a PostgreSQL service/container
4. Secrets/credentials are passed via environment variables, not hardcoded
5. Test artefacts (containers) are torn down after tests run (docker-compose down, --rm, or equivalent)
6. Agent configured vitest with tree reporters
7. Agent generated test trees under ## Requirements in CLAUDE.md
8. Agent did NOT write any test implementations' ;;

  *) echo "Unknown test: $TEST_NAME" >&2; exit 1 ;;
esac

# Extract narrative from transcript
NARRATIVE="$(jq -r '
  select(.type == "assistant") |
  .message.content[]? // empty |
  if .type == "text" then "TEXT: " + .text
  elif .type == "tool_use" then "TOOL: " + .name + " — " + (.input | tostring | .[0:200])
  else empty end
' "$TRANSCRIPT" 2>/dev/null)"

# Build prompt
PROMPT="You are analysing a functional test transcript. For each criterion, report PASS or FAIL with a one-line justification. End with a summary line.

## Transcript

$NARRATIVE

## Criteria

$CRITERIA"

# Run analysis — clean Docker environment, no plugins
claude -p "$PROMPT" \
  --model haiku \
  --max-budget-usd 0.25 \
  --no-session-persistence
