---
name: climb
description: Climb up a level of abstraction — completely. Mines the user's Claude Code session transcripts at build time and produces the user-specific artefacts (ambient manual, antipatterns, precedents) the Climber plugin's test-time skills will consume. All transcript work happens here; test-time skills never touch raw transcripts. TRIGGER when the user says /climb, "make me a clone", "make me a director / proxy agent", "write instructions for my proxy agent", "step up a level of abstraction on coding work", or similar.
---

# Climb

Build the user's clone artefacts. Climber's test-time skills (`review-turn`, `predict-user`, `refactor-rulebook`) consume what this skill produces; they never touch raw transcripts. All mining lives here.

Artefacts land in `~/.claude/climber/`:

```
~/.claude/climber/
  manual.md        — the ambient rulebook; user reads at start of clone sessions
  antipatterns.md  — review-turn's if-then list
  precedents.md    — predict-user's decision table
  lessons.md       — two-halved human-readable doc (for the user, not the clone)
```

## Principles

- **Autonomy is the goal.** The clone decides and acts; escalation is epistemic only.
- **Build vs test time.** All transcript work happens here. Test-time skills consume artefacts.
- **Grow by subtraction.** Every artefact tightens existing lines before appending; the rulebook shrinks as it matures.
- **Preserve the user's voice.** Quote or paraphrase actual corrections. Don't normalise.

## Process

### 1. DISCOVER

- List `~/.claude/projects/*/*.jsonl`. Report total + highest-activity directories.
- Skip / sample `subagents/` subdirectories; low user-signal.
- If fewer than ~30 direct-user transcripts, tell the user and ask whether to proceed.

### 2. MINE — parallel subagents, two waves

Dispatch via `run_in_background: true` so the main context stays clean.

**Wave A — explicit patterns.** 3–5 agents partitioned across project directories. Grep for stated corrections/preferences (`don't`, `stop`, `never`, `always`, `instead`, `prefer`, `we don't`, `you should`, `the reason`, `because`, `wrong`, `actually`, `rule:`). Ignore Claude's own text, system reminders, hook output, static SessionStart rules, one-off task instructions. Return deduplicated principles by theme with occurrence counts.

**Wave B — implicit patterns.** 3 agents, each a distinct lens. Each told NOT to repeat wave A.

- **Lens 1 — correction triggers & frustration.** Characterise Claude's BEHAVIOUR before short interruptions ("no", "stop", "huh?", "wrong", "actually", "wait") or frustration markers (profanity, CAPS). Probe for: preamble/recap, "shall I proceed?" theatre, trade-off tables answering yes/no, menus after decisions, plan-doc editing mid-conversation, fabricated content, adjacent work the user reserved, "for consistency" smuggling, partial-read → proposal, racing past unresolved questions, unasked renames, silent error swallowing, defensive defaults.
- **Lens 2 — taste from acceptance/rejection.** What accepted-vs-rejected proposals reveal: loaded vocabulary with specific meanings, unusual structural choices, the "Claude worried, user shrugged" cases.
- **Lens 3 — cross-session meta-patterns.** Same lesson re-taught in new clothing; session rhythm (openers, `/clear` vs new session, abandoned threads); division-of-labour signals; recurring friction.

Each returns bulleted lessons with 2–3 concrete citations.

### 3. WRITE ARTEFACTS

Ensure `~/.claude/climber/` exists. Then:

**`lessons.md`** — two-halved human-readable document (EXPLICIT / IMPLICIT). For the user's review; not consumed by skills.

**`manual.md`** — the ambient rulebook the clone reads at the start of every session. Tight. Sections:

- **Role & autonomy.** The clone directs; it does not write code. Act. Escalate only on deep epistemic uncertainty.
- **VISION.md.** Once you understand the work, write `./VISION.md` at the project root stating what done looks like in the consumer's vocabulary. Tighten it when scope changes. When the work is genuinely done, add a line `Status: Achieved` — this tells the Stop hook to stop blocking. Until then, keep driving; a Stop hook will block turn-end to keep you climbing. Escalations must be phrased as questions (end with `?`) so the hook yields to the user.
- **Prompt shape.** Drawn from the user's opener patterns — typically: log/terminal paste + pointed question; imperative; no preamble; `@path` references; plan-first by default for investigation.
- **Vocabulary.** Load-bearing terms from Lens 2. Explicit rejection of overloads. Active every turn.
- **Protocols.** Numbered replies, "actually" = scope change, "are you sure?" = go look at named source, "wrong" + evidence = restart from evidence, short "no" = branch closed. Hot-loop fragments vs cold-start framed prompts.
- **Verification.** Read the diff yourself, tail the logs, check against named sources. Observability-in, not explanation-out.
- **Taste defaults.** How to pick between two valid paths, from Lens 2.
- **Session hygiene.** Openers, new-session-over-/clear, one concern per session, close dead sessions fast.
- **When to ask the user.** Epistemic only. If you can predict the answer from context, prior decisions, or this manual, don't ask. Examples where uncertainty is more common (but not automatic escalation): destructive/irreversible ops, test-tree / Mental-Model changes, public-contract changes, explicit fences. Spinning several turns with no artefact = close, don't ask. When you do ask, end the message with a `?` so the Stop hook yields.
- **Tooling defaults.** Commands/tool choices the user always uses.
- **Handoff format.** One-line summary + diff path + numbered queued decisions. No narrative.
- **Signals.** How to read the user's reactions if they chime in.
- **Skill orchestration.**
  - After every non-trivial coding-agent turn, invoke **review-turn**.
  - Before asking the user anything, invoke **predict-user**.
  - When you learn a new pattern, invoke **refactor-rulebook**.

**`antipatterns.md`** — `review-turn`'s if-then rules. One entry per antipattern from Lens 1:

```
## <pattern name>
Trigger: <what the coding agent did>
Response: <what the clone does>
Evidence: <1–2 transcript citations>
```

Order by frequency. Compress aggressively — this file is read on every coding-agent turn.

**`precedents.md`** — `predict-user`'s decision table. One entry per non-obvious past decision:

```
## <situation title>
Situation: <what was at stake, in enough detail to match against>
Chose: <what the user picked>
Why: <in the user's voice if possible>
Generalise: <how this applies to adjacent situations>
```

Sort and compress — this file is read per-invocation.

### 4. REPORT

Print:
- Path to `~/.claude/climber/lessons.md` (for the user to review).
- Path to `~/.claude/climber/manual.md` (injected into every session where climber is enabled via the SessionStart hook — no paste required).
- Confirm `antipatterns.md` and `precedents.md` are in place.
- Remind the user to install climber in any project they want the clone active in: `claude plugin install climber@susu-eng --scope project`.

## When to re-run

- Working style shifts (new project type, new collaboration mode).
- Clone output feels off — re-mine and re-build.
- Manual has grown without subtracting — re-run against current transcripts.
