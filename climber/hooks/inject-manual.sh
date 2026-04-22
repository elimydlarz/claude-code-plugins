#!/usr/bin/env bash
MANUAL="$HOME/.claude/climber/manual.md"

if [ -f "$MANUAL" ]; then
  printf '# Clone Manual\n\n'
  cat "$MANUAL"
fi

exit 0
