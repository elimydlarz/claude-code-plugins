#!/usr/bin/env bash
NUDGE_DIR="${CONTREE_NUDGE_DIR:-$HOME/.claude/contree/nudges/20-20-20}"
THRESHOLD=1200

INPUT=$(cat)

mkdir -p "$NUDGE_DIR" 2>/dev/null || exit 0

NUDGE_BASELINE=$(ls -t "$NUDGE_DIR" 2>/dev/null | head -1)

SESSION_BASELINE=""
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  START_STR=$(jq -r 'select(.timestamp != null) | .timestamp' "$TRANSCRIPT" 2>/dev/null | head -1)
  if [ -n "$START_STR" ]; then
    START_STR=$(printf '%s' "$START_STR" | sed 's/\.[0-9]*Z$/Z/')
    if date -j >/dev/null 2>&1; then
      SESSION_BASELINE=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$START_STR" +%s 2>/dev/null) || SESSION_BASELINE=""
    else
      SESSION_BASELINE=$(date -u -d "$START_STR" +%s 2>/dev/null) || SESSION_BASELINE=""
    fi
  fi
fi

if [ -n "$NUDGE_BASELINE" ] && [ -n "$SESSION_BASELINE" ]; then
  if [ "$SESSION_BASELINE" -gt "$NUDGE_BASELINE" ]; then
    BASELINE="$SESSION_BASELINE"
  else
    BASELINE="$NUDGE_BASELINE"
  fi
elif [ -n "$NUDGE_BASELINE" ]; then
  BASELINE="$NUDGE_BASELINE"
elif [ -n "$SESSION_BASELINE" ]; then
  BASELINE="$SESSION_BASELINE"
else
  exit 0
fi

NOW=$(date +%s)
ELAPSED=$(( NOW - BASELINE ))

if [ "$ELAPSED" -ge "$THRESHOLD" ]; then
  touch "$NUDGE_DIR/$NOW"
  MESSAGE='Before addressing the user’s request, mention the 20-20-20 rule: they have been at the keyboard for a while. Say something like: "Quick eye break: look at something 20 feet away for 20 seconds (20-20-20 rule)." Keep it brief, then continue with their request.'
  jq -n --arg msg "$MESSAGE" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $msg}}'
fi

exit 0
