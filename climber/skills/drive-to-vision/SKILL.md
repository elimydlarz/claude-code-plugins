---
name: drive-to-vision
description: Take the next concrete step toward VISION.md — read current state, identify the smallest actionable gap, act on it, verify. TRIGGER when the Stop hook directs the clone to drive, at the start of a new clone session with an existing VISION.md, and whenever the clone needs to pick the next step toward done.
---

Sequence the clone toward VISION.md. One step per invocation — the Stop hook calls this again on the next turn, creating the loop.

## Steps

1. **Read `./VISION.md`.** If it doesn't exist, the clone is in vision-definition phase — ask the user narrowly (end with `?`) for the minimum needed to write it, then stop. Do not continue this skill.

2. **If VISION.md is marked `Status: Achieved`,** report completion to the user and stop driving. Do not continue.

3. **Read current state.** Compare VISION to what's actually on disk / in the session so far. Don't plan — observe.

4. **Pick the smallest actionable gap.** One concrete next step — not a multi-step plan. Prefer: a file to read, a subagent to dispatch, a command to run, a decision to make. Smallest unit that moves the needle.

5. **Before escalating to the user, invoke `predict-user`.** If it returns high or medium, act on the prediction. Only on `low` should you ask — and phrase it as a question so the Stop hook yields.

6. **Take the step.** Use the clone manual for HOW — this skill only sequences; the manual supplies taste, protocols, verification defaults, and tooling choices.

7. **Verify the result.** Observability-in, not explanation-out. Read the diff, tail the logs, check against named sources — whatever the manual prescribes for this kind of work.

8. **If VISION.md is now achieved,** add `Status: Achieved` to it on a dedicated line.

9. **Return.** The Stop hook will re-invoke this skill on the next turn unless VISION is marked achieved or the escalation is underway.

## Invariants

- **One action per invocation.** Do not chain steps. The loop iterates across turns, not inside this skill.
- **Never write code yourself.** Dispatch the coding agent. The clone directs.
- **Never ask the user without first invoking `predict-user`.**
- **Never skip verification.** A step not verified is not a step taken.
- **Never tighten or rewrite VISION.md** unless the user has changed scope. VISION is the contract, not scratch paper.
