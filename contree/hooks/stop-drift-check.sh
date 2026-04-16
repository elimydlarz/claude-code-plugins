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

echo 'Guard the contract. (1) Has implementation drifted from test trees in ## Requirements? Test trees are the contract between intent and implementation — never modify them silently. If drift exists, ask the user: update test trees and tests to reflect the implementation, or pare implementation back to match the test trees? (2) Has the public API or behaviour changed in a way not reflected in ## Mental Model? Any new parameter, changed signature, added capability, or removed feature means the Mental Model needs updating. (3) Does README.md accurately describe the current state of the project? If nothing needs attention, reply only with 0.' >&2
exit 2
