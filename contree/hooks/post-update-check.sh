#!/usr/bin/env bash
INPUT=$(cat)

CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
export CLAUDE_PROJECT_DIR

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

MATCHED_MENTAL_MODEL=0
if [ "${FILE_PATH##*/}" = "MENTAL_MODEL.md" ]; then
  MATCHED_MENTAL_MODEL=1
fi

if [ "$MATCHED_MENTAL_MODEL" -eq 0 ]; then
  while IFS= read -r PATCH_PATH; do
    if [ "${PATCH_PATH##*/}" = "MENTAL_MODEL.md" ]; then
      MATCHED_MENTAL_MODEL=1
      break
    fi
  done < <(
    printf '%s' "$INPUT" \
      | jq -r '.tool_input.command // empty' 2>/dev/null \
      | awk '
        /^\*\*\* (Add|Update|Delete) File: / {
          sub(/^\*\*\* (Add|Update|Delete) File: /, "")
          print
        }
      '
  )
fi

[ "$MATCHED_MENTAL_MODEL" -eq 1 ] || exit 0

FINDINGS=$(bash "${CLAUDE_PLUGIN_ROOT}/hooks/validate-mental-model.sh")

if [ -n "$FINDINGS" ]; then
  jq -nc --arg msg "MENTAL_MODEL.md validator findings:
$FINDINGS" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
fi

exit 0
