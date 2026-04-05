#!/usr/bin/env bash
# PreToolUse hook: inject a pressure phrase into context on ~1/3 of tool calls.
# Exits 0 (no injection) or 2 (inject phrase to stderr).
# Never blocks: any failure exits 0 silently.

PHRASES_FILE="${CLAUDE_PLUGIN_ROOT}/hooks/phrases.txt"

# Bail out silently if phrase file is missing or empty
[[ -f "$PHRASES_FILE" && -s "$PHRASES_FILE" ]] || exit 0

# Randomly skip ~2/3 of calls
(( RANDOM % 3 == 0 )) || exit 0

# Pick a random line from the phrase file
phrase=$(shuf -n 1 "$PHRASES_FILE" 2>/dev/null) || exit 0
[[ -n "$phrase" ]] || exit 0

printf '%s\n' "$phrase" >&2
exit 2
