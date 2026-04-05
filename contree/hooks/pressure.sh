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
line_count=$(wc -l < "$PHRASES_FILE" | tr -d ' ')
(( line_count > 0 )) || exit 0
line_num=$(( (RANDOM % line_count) + 1 ))
phrase=$(sed -n "${line_num}p" "$PHRASES_FILE")
[[ -n "$phrase" ]] || exit 0

printf '%s\n' "$phrase" >&2
exit 2
