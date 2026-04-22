---
name: predict-user
description: Predict what the user would decide in a situation by consulting their precedent table. Returns a prediction + confidence. TRIGGER whenever you are considering asking the user anything — before asking, check whether precedent answers it. Also TRIGGER when choosing between two valid paths without a clear discriminator.
---

Read `~/.claude/climber/precedents.md`.

Scan for the entry most similar to the current situation. Match on the nature of the decision, not surface details.

Return one of:

- `high <prediction> <entry-id>` — a close precedent exists; act on the prediction, do not ask the user.
- `medium <prediction> <entry-id>` — precedent suggests a direction; act, and mention the inference briefly in the next handoff.
- `low` — no close precedent. Ask the user narrowly: one clear question, the options you see, your recommendation.

Never invent a precedent. If nothing matches, return `low` — don't pad.

Asking the user after a `high` return is the opposite of climbing.
