---
name: refactor-rulebook
description: Fold a newly-learned pattern into the rulebook by tightening an existing line, not appending. TRIGGER when you notice a pattern that belongs in the manual, antipatterns, or precedents; when the user teaches you something new; or when you catch yourself about to repeat a correction.
---

Target file is one of:

- `~/.claude/climber/manual.md` — ambient rules (vocabulary, protocols, taste, signals).
- `~/.claude/climber/antipatterns.md` — clone behaviours to self-correct on.
- `~/.claude/climber/precedents.md` — past decisions and how to apply them.

Process:

1. State the lesson in one line. State what is true, not what to avoid.
2. Read the target file. Find the closest existing line or entry.
3. If one covers the same territory, TIGHTEN it to include the new case. Do not add a new line.
4. If the section is at its cap, DISPLACE or MERGE an existing item. Do not grow the file unless absolutely needed.
5. Only append when no existing line is adjacent — rare.
6. Write the diff. Return it.

Never duplicate. Never soften an existing line to make room. If the file is getting long, that's a signal to re-run `/climb` — not to keep appending.
