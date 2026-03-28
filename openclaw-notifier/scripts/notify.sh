#!/usr/bin/env bash
set -euo pipefail

# No-op when not running under OpenClaw
[ -z "${OPENCLAW_URL:-}" ] && exit 0

INPUT=$(cat)

# Build /hooks/agent payload from SubagentStop event
PAYLOAD=$(printf '%s' "$INPUT" | jq '{
  message: ("Subagent \(.agent_type // "unknown") completed: agent_id=\(.agent_id // "unknown") reason=\(.reason // "unknown")"),
  name: "subagent-complete"
}')

CURL_ARGS=(-s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 -X POST -H 'Content-Type: application/json')
[ -n "${OPENCLAW_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${OPENCLAW_TOKEN}")

HTTP_CODE=$(curl "${CURL_ARGS[@]}" -d "$PAYLOAD" "${OPENCLAW_URL}/hooks/agent" 2>/dev/null) || true

case "$HTTP_CODE" in
  2??) ;;
  *) echo "openclaw-notifier: POST ${OPENCLAW_URL}/hooks/agent returned $HTTP_CODE" >&2 ;;
esac

exit 0
