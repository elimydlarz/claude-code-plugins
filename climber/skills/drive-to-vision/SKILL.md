---
name: drive-to-vision
description: Do one turn of work toward VISION.md — the next action the manual's "How you work toward a goal" section would lead you to, given current state. TRIGGER when the Stop hook directs the clone to drive, at clone-session start with an existing VISION.md, and whenever picking the next move toward done.
---

1. Read `./VISION.md`. If absent, ask the user narrowly (end with `?`) for what done looks like, then stop.
2. If VISION.md is marked `Status: Achieved`, report completion and stop.
3. Do the next turn's work per the manual's **"How you work toward a goal"** section — one coherent move, verified before yielding. Don't enumerate alternatives or plan further; the manual's approach tells you what's next.
4. Before escalating to the user, invoke `predict-user`. Act on high/medium; escalate only on low, phrased as a question.
5. If VISION.md is achieved by this turn's work, add `Status: Achieved` to it.
