---
name: diff-for-humans
description: "Generate a single image that explains the current change to a human, using OpenAI's gpt-image-2 model — foregrounding the technical substance the change touches (contracts, databases, behaviour, test trees). TRIGGER when: the user runs /diff-for-humans, or asks to see, picture, illustrate, or visualise the current change or diff."
---

# Diff for Humans

Turns the current change into one image — a picture of what this diff does, made legible to a human — using OpenAI's **gpt-image-2** model. The image is technical, not decorative: it shows the concrete elements the change touches (contracts, databases, behaviour, test trees), not an abstract metaphor. Invoked on demand; nothing fires automatically.

## When to Use

- The user runs `/diff-for-humans`.
- The user asks to see, picture, illustrate, or visualise the current change.

## Process

### 1. Read the change

Work out *what* to depict before reading it. Rely on natural language, not on a fixed git boundary:

- **If the user gave a natural-language indication** of what to depict — "the second-opinion change", "the last thing we did" — depict exactly that.
- **Absent a clear indication**, depict the **last non-trivial, naturally grouped change**. Do not equate the change with a single commit: **trunk-sync** commits continuously, so one logical change is smeared across many tiny auto-commits. Do not limit yourself to the working tree either — it is often empty once trunk-sync has committed. Read the recent history and the working tree together, skip trivial commits (version bumps, formatting, the sync's own noise), and assemble the most recent coherent unit of work.

Gather that change as a diff. For the working tree plus any new untracked files (the common case):

```bash
CHANGE=$(git diff HEAD; git ls-files --others --exclude-standard | while read -r f; do git diff --no-index -- /dev/null "$f"; done)
```

For a wider grouping spanning several trunk-sync commits, diff the appropriate range instead. If there are no non-trivial changes to depict, say so and stop — there is nothing to depict.

### 2. Decide what the image should depict

The image is an editorial choice, not a transcription of the diff. Decide what to depict from four inputs:

- **the nature of the change** — a new capability, a refactor, a bug fix, a deletion, a config change? The kind of change sets the visual register.
- **the technical substance** — foreground the concrete technical elements the change actually touches: the **contracts** and interfaces it changes, the **data and databases** (schemas, tables, migrations, records) it reads or writes, the **behaviour** it adds or alters, and the **test trees** that hold it to account. Render these as legible technical objects — a labelled schema, a contract boundary, a tree of behaviours — not as an abstract metaphor that hides the engineering. A teammate should be able to read the moving parts off the picture.
- **the important details** — the one or two things a viewer most needs to grasp. Leave the rest out; an image that shows everything shows nothing.
- **the intended audience** — a teammate reviewing the PR, a non-technical stakeholder, your future self. The audience sets the vocabulary and the level of abstraction.

### 3. Generate the image with gpt-image-2

Call OpenAI's images generations API with the `gpt-image-2` model (pinned id `gpt-image-2-2026-04-21`), authenticated with `OPENAI_API_KEY`. Write a prompt that captures your step-2 decisions. gpt-image-2 always returns base64 in `data[0].b64_json` — do not send a `response_format` parameter, the API rejects it. Decode the base64 and save the returned image as a `.png` file in the project.

```bash
OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}"

curl -sS -X POST "$OPENAI_BASE_URL/images/generations" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg prompt "$PROMPT" '{
        model: "gpt-image-2-2026-04-21",
        prompt: $prompt,
        size: "1024x1024",
        quality: "high"
      }')" \
  | jq -r '.data[0].b64_json' | base64 --decode > diff.png
```

### 4. Surface your choices

Show the saved image's path and surface the choices you made for the user to review: what you depicted, which details you foregrounded and which you dropped, and the audience you pitched it at. The user reviews — they may ask you to redraw with different choices.

## Failure is loud

If the gpt-image-2 request fails — missing `OPENAI_API_KEY`, an API error, a non-2xx response, or empty `data` — surface the failure as an error and stop. Never fabricate an image, write a placeholder file, or report success you did not get. A missing image is an honest outcome; a fake one is not.
