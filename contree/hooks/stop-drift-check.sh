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

cat >&2 <<'EOF'
(1) MENTAL MODEL: Did this task reveal something a future agent could not recover from code and tests, and whose removal would cause a mistake a competent human would not make? Default is no change.

If a change is warranted:
  - Name which of the seven sections it belongs to (Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, Temporal View).
  - If none fits, it is not part of the mental model.
  - Prefer tightening an existing line over adding a new one.
  - State what is true, not what to avoid.
  - When the target section is at its cap, displace or merge an existing item rather than appending.

(2) TEST TREES: Have test trees and implementation drifted apart? If so, propose solutions.

(3) CLAUDE.md: Has CLAUDE.md content drifted from reality? If so, update it.

(4) README: Is the readme out of date now? If so, update it.

If nothing needs attention, reply 0.
EOF
exit 2
