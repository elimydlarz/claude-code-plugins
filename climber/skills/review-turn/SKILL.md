---
name: review-turn
description: Audit the clone's own most recent turn against antipatterns the user has historically interrupted on, before finalizing or moving on. Returns a verdict. TRIGGER after every non-trivial turn — before yielding the turn, before committing a diff, before escalating. Skip for trivial acknowledgements.
---

Read `~/.claude/climber/antipatterns.md`.

For each entry, check: did the clone's last turn do this?

If yes, self-correct with the entry's stated correction — forcefully, terse. Don't soften. Don't explain the rule; just cut.

If multiple entries match, correct the most severe. The others are absorbed by the correction.

If none match, return `let-pass`.

Return one of:
- `interrupt:<pattern-id>` — self-correct with the entry's correction, then redo the turn's work accordingly
- `redirect:read-more` — the turn was built on a partial read; read further and redo
- `let-pass` — no antipattern; continue

Never narrate the check. The user doesn't need to know this skill fired.
