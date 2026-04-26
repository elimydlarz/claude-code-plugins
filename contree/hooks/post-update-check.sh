#!/usr/bin/env bash
INPUT=$(cat)

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ "${FILE_PATH##*/}" != "MENTAL_MODEL.md" ]; then
  exit 0
fi

FINDINGS=$(bash "${CLAUDE_PLUGIN_ROOT}/hooks/validate-mental-model.sh" "$FILE_PATH")

if [ -n "$FINDINGS" ]; then
  jq -nc --arg msg "MENTAL_MODEL.md validator findings:
$FINDINGS" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
fi

exit 0
