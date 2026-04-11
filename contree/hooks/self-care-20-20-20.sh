#!/usr/bin/env bash
NUDGE_DIR="${CONTREE_NUDGE_DIR:-$HOME/.claude/contree/nudges/20-20-20}"
THRESHOLD=1200

INPUT=$(cat)

mkdir -p "$NUDGE_DIR" 2>/dev/null || exit 0

# Baseline: most recent nudge file (filename = unix timestamp), else session start from
# the transcript. Nudge-file baseline is tried first so we don't need the transcript to
# exist — in `claude -p` mode, the transcript file has not yet been written when
# UserPromptSubmit fires.
LATEST=$(ls -t "$NUDGE_DIR" 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
  BASELINE="$LATEST"
else
  TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
  if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    exit 0
  fi
  START_STR=$(jq -r 'select(.timestamp != null) | .timestamp' "$TRANSCRIPT" 2>/dev/null | head -1)
  [ -z "$START_STR" ] && exit 0
  # Strip fractional seconds (e.g. 2026-04-11T09:30:13.325Z -> 2026-04-11T09:30:13Z)
  START_STR=$(printf '%s' "$START_STR" | sed 's/\.[0-9]*Z$/Z/')
  if date -j >/dev/null 2>&1; then
    BASELINE=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$START_STR" +%s 2>/dev/null) || exit 0
  else
    BASELINE=$(date -u -d "$START_STR" +%s 2>/dev/null) || exit 0
  fi
fi

NOW=$(date +%s)
ELAPSED=$(( NOW - BASELINE ))

if [ "$ELAPSED" -ge "$THRESHOLD" ]; then
  touch "$NUDGE_DIR/$NOW"
  MESSAGE='Before addressing the user’s request, mention the 20-20-20 rule: they have been at the keyboard for a while. Say something like: "Quick eye break: look at something 20 feet away for 20 seconds (20-20-20 rule)." Keep it brief, then continue with their request.'
  jq -n --arg msg "$MESSAGE" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $msg}}'
fi

exit 0
