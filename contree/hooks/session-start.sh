#!/usr/bin/env bash
# SessionStart hook: print rules cheatsheet plus one random pressure phrase to stdout.
# Claude Code injects SessionStart stdout (exit 0) into the model's context.

CHEATSHEET="${CLAUDE_PLUGIN_ROOT}/rules/cheatsheet.md"
PHRASES="${CLAUDE_PLUGIN_ROOT}/hooks/phrases.txt"

cat "$CHEATSHEET"

if [[ -f "$PHRASES" && -s "$PHRASES" ]]; then
  line_count=$(wc -l < "$PHRASES" | tr -d ' ')
  if (( line_count > 0 )); then
    line_num=$(( (RANDOM % line_count) + 1 ))
    phrase=$(sed -n "${line_num}p" "$PHRASES")
    if [[ -n "$phrase" ]]; then
      printf '\n%s\n' "$phrase"
    fi
  fi
fi

exit 0
