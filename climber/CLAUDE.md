# climber

Build an autonomous clone that directs a Claude Code session the way you do, so you can climb up a level of abstraction completely.

## Test Trees

See [TEST_TREES.md](TEST_TREES.md) — the definition of functional and cross-functional requirements.

## Mental Model

Climber splits the job into **build time** and **test time**:

- **Build time** — the `/climb` skill mines the user's Claude Code transcripts (`~/.claude/projects/**/*.jsonl`) and produces user-specific artefacts under `~/.claude/climber/`:
  - `manual.md` — the ambient rulebook; the user pastes this into a clone session.
  - `antipatterns.md` — the if-then list `review-turn` consumes.
  - `precedents.md` — the decision table `predict-user` consumes.
  - `lessons.md` — two-halved human-readable doc (explicit + implicit) for the user to review.
- **Test time** — the clone operates a Claude Code session on the user's behalf. Three skills fire on their triggers and consume the artefacts. **No skill ever touches raw transcripts at test time.** A **SessionStart hook** (`hooks/inject-manual.sh`) reads `~/.claude/climber/manual.md` and injects it as session context, so the clone is ambient from turn one without the user pasting anything. A **Stop hook** (`hooks/drive-to-vision.sh`) enforces climbing: while `./VISION.md` exists and isn't marked `Status: Achieved`, it blocks turn-end and nudges the clone to keep driving. It yields when the clone's last message ends with `?` (escalation), when VISION.md is absent (vision-definition phase), or when it's marked achieved.

**Per-project opt-in.** Claude Code installs plugin code user-level, but activation is scoped. In each project where you want the clone active, run from the project root:

```
claude plugin install climber@susu-eng --scope project
```

This writes the enablement into the project's `.claude/settings.json` — commit it so teammates inherit the opt-in. In projects without this entry, the plugin's hooks and skills never fire.

## Skills

- `climb` — build-time mining + artefact generation. Trigger: `/climb` or equivalent requests.
- `review-turn` — audits the coding agent's most recent turn against `antipatterns.md`; returns a verdict. Trigger: after every non-trivial coding-agent turn.
- `predict-user` — consults `precedents.md` before the clone asks the user anything; returns a prediction + confidence. Trigger: before escalating or when choosing between two valid paths.
- `refactor-rulebook` — enforces tighten-existing-line over append when folding a new lesson into one of the artefacts. Trigger: when the clone learns something new.

## Principles

- **Autonomy is the goal.** The clone asks the user only when it is deeply unsure what they would do. If it can predict from context, prior decisions, or the rulebook, it acts.
- **Build vs test time.** All transcript work is `/climb`. Test-time skills consume artefacts.
- **Grow by subtraction.** Artefacts tighten existing lines before appending. Files that grow without subtracting are a signal to re-run `/climb`.
- **Preserve the user's voice.** Quote their actual corrections; don't normalise.

## Installation

Install from the `susu-eng` marketplace:

```
/plugin marketplace add elimydlarz/claude-code-plugins
/plugin install climber@susu-eng
```

Then run `/climb` once to populate `~/.claude/climber/`. To activate the clone in a project, add `.claude/settings.json` at the project root with:

```json
{
  "enabledPlugins": {
    "climber@susu-eng": true
  }
}
```

In opted-in projects, the SessionStart hook injects `~/.claude/climber/manual.md` automatically, the three test-time skills fire on their triggers, and the Stop hook drives toward `VISION.md`. In projects without this entry, climber stays dormant.

## Publishing

```
pnpm publish:climber patch   # or minor, major
```
