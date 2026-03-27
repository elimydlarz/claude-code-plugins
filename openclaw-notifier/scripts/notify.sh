#!/usr/bin/env bash
set -euo pipefail

# No-op when not running under OpenClaw
[ -z "${OPENCLAW_URL:-}" ] && exit 0

INPUT=$(cat)

CURL_ARGS=(-s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 -X POST -H 'Content-Type: application/json' -4)
[ -n "${OPENCLAW_TOKEN:-}" ] && CURL_ARGS+=(-H "Authorization: Bearer ${OPENCLAW_TOKEN}")

HTTP_CODE=$(curl "${CURL_ARGS[@]}" -d "$INPUT" "${OPENCLAW_URL}/api/subagent-complete" 2>/dev/null) || true

case "$HTTP_CODE" in
  2??) ;;
  *) echo "openclaw-notifier: POST ${OPENCLAW_URL}/api/subagent-complete returned $HTTP_CODE" >&2 ;;
esac

exit 0
