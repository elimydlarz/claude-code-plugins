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

echo '(1) Is there any inconsistency between test trees in ## Requirements and the implementation, in either direction? If so, propose solutions to the user. (2) Has the public API or behaviour changed in a way not reflected in ## Mental Model? Any new parameter, changed signature, added capability, or removed feature means the Mental Model needs updating. (3) Does README.md accurately describe the current state of the project? If nothing needs attention, reply only with 0.' >&2
exit 2
