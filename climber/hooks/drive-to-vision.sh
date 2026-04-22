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
VISION.md exists and is not marked achieved. Invoke the `drive-to-vision` skill to take the next concrete step.
EOF
exit 2
