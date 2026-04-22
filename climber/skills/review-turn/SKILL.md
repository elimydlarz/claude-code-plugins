---
name: review-turn
description: Audit the coding agent's most recent turn against antipatterns the user has historically interrupted on, before deciding how to respond. Returns a verdict. TRIGGER after every non-trivial coding-agent turn — before letting it continue, before approving a diff, before handing off. Skip for trivial acknowledgements.
---

Read `~/.claude/climber/antipatterns.md`.

For each entry, check: did the coding agent's last turn do this?

If yes, respond with the entry's stated correction — forcefully, terse. Don't soften. Don't explain the rule; just cut.

If multiple entries match, respond to the most severe. The others are absorbed by the correction.

If none match, return `let-pass`.

Return one of:
- `interrupt:<pattern-id>` — interrupt with the entry's correction
- `redirect:read-more` — the proposal was built on a partial read; tell it to read and return
- `let-pass` — no antipattern; continue

Never narrate the check. The coding agent doesn't need to know this skill fired.
