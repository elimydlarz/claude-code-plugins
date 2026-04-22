#!/usr/bin/env bash
INPUT=$(cat)

if printf '%s' "$INPUT" | jq -e '.stop_hook_active' 2>/dev/null | grep -q true; then
  exit 0
fi

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  LAST_CHAR=$(jq -rs '
    ([.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text] | last // "")
    | sub("[[:space:]]+$"; "")
    | if length > 0 then .[-1:] else "" end
  ' "$TRANSCRIPT" 2>/dev/null)
  if [ "$LAST_CHAR" = "?" ]; then
    exit 0
  fi
fi

if [ ! -f VISION.md ]; then
  exit 0
fi

if grep -qiE '^[[:space:]]*Status:[[:space:]]*Achieved[[:space:]]*$' VISION.md; then
  exit 0
fi

cat >&2 <<'EOF'
VISION.md exists and is not marked achieved. Do not stop driving.

- If you were about to ask the user, first invoke predict-user. Act on high/medium; only escalate on low, and phrase the escalation as a question so this hook yields.
- If VISION.md is actually achieved, add a line `Status: Achieved` to VISION.md and stop on the next turn.
- Otherwise, take the next concrete step toward VISION.md (dispatch, review, or tighten VISION.md).
EOF
exit 2
