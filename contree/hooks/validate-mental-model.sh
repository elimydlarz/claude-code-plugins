#!/usr/bin/env bash

if [ -z "$CLAUDE_PROJECT_DIR" ]; then
  printf 'validate-mental-model.sh requires CLAUDE_PROJECT_DIR\n' >&2
  exit 1
fi

FILE="$CLAUDE_PROJECT_DIR/MENTAL_MODEL.md"

if [ ! -f "$FILE" ]; then
  printf 'MENTAL_MODEL.md is missing\n'
  exit 0
fi

awk '
BEGIN {
  caps["Core Domain Identity"] = 5
  caps["World-to-Code Mapping"] = 15
  caps["Ubiquitous Language"] = 30
  caps["Bounded Contexts"] = 7
  caps["Invariants"] = 10
  caps["Decision Rationale"] = 7
  caps["Temporal View"] = 10
}
/^## / {
  section = substr($0, 4)
  if (!(section in caps)) {
    printf "%s is a rogue heading, not one of the seven named sections\n", section
  } else {
    seen[section] = 1
  }
  next
}
/^[-*] / && section {
  count[section]++
}
END {
  for (s in caps) {
    if (!(s in seen)) {
      printf "%s section is missing\n", s
    }
  }
  for (s in count) {
    if (caps[s] && count[s] > caps[s]) {
      printf "%s exceeds its cap of %d (has %d items)\n", s, caps[s], count[s]
    }
  }
}
' "$FILE"
