#!/usr/bin/env bash
set -euo pipefail

# Extracts key actions (tool calls) from functional test transcripts.
# Usage: ./analyse-transcripts.sh [test-name]
#   No args: analyse all transcripts
#   With arg: analyse one transcript

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

extract_actions() {
  local file="$1"
  local name
  name="$(basename "$file" -transcript.jsonl)"
  echo "=== $name ==="

  # Extract tool_use entries: name and key input fields
  jq -r '
    select(.type == "assistant") |
    .message.content[]? |
    select(.type == "tool_use") |
    if .name == "Skill" then "  SKILL: \(.input.skill) \(.input.args // "")"
    elif .name == "Write" then "  WRITE: \(.input.file_path)"
    elif .name == "Edit" then "  EDIT: \(.input.file_path)"
    elif .name == "Bash" then "  BASH: \(.input.command | .[0:120])"
    elif .name == "Read" then "  READ: \(.input.file_path)"
    elif .name == "Glob" then "  GLOB: \(.input.pattern)"
    elif .name == "Grep" then "  GREP: \(.input.pattern)"
    else "  \(.name)"
    end
  ' "$file" 2>/dev/null || echo "  (failed to parse)"

  echo ""
}

if [ "${1:-}" ]; then
  extract_actions "$SCRIPT_DIR/${1}-transcript.jsonl"
else
  for f in "$SCRIPT_DIR"/*-transcript.jsonl; do
    [ -f "$f" ] && extract_actions "$f"
  done
fi
