#!/usr/bin/env bash
INPUT=$(cat)

if printf '%s' "$INPUT" | jq -e '.stop_hook_active' 2>/dev/null | grep -q true; then
  exit 0
fi

CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

if [ ! -f "$CLAUDE_PROJECT_DIR/MENTAL_MODEL.md" ]; then
  echo "MENTAL MODEL: MENTAL_MODEL.md is missing at the project root. Create it with these seven H2 sections in order: Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, Temporal View. Each section starts with a one-line placeholder describing what belongs there until real content lands." >&2
else
  echo "MENTAL MODEL: Did this task reveal any knowledge NOT already described in documentation, tests, and code? Default is no change. If a change is warranted: name which of the seven sections it belongs to (Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, Temporal View); if none fits, it is not part of the mental model; prefer tightening an existing line over adding a new one; state what is true, not what to avoid; when the target section is at its cap, displace or merge an existing item rather than appending." >&2
fi

echo "TEST TREES: Have test trees and implementation drifted apart? If so, propose solutions." >&2
echo "CLAUDE.md: Has CLAUDE.md content drifted from reality? If so, update it." >&2

if [ ! -f "$CLAUDE_PROJECT_DIR/README.md" ]; then
  echo "README: README.md is missing at the project root. Create it so consumers can understand what the project is, how to install it, how to configure it, and how to use it." >&2
else
  echo "README: Is the README out of date now? It should tell consumers what the project is, how to install it, how to configure it, and how to use it. If anything is stale or wrong, update it." >&2
fi

echo "If nothing needs attention, reply 0." >&2
exit 2
