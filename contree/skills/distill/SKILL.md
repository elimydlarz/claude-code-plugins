---
name: distill
description: "Distill CLAUDE.md down to its essence when it has grown too large, without losing the contract. Preserves test trees verbatim, tightens prose, ranks the rest by evidence from past transcripts. TRIGGER when: CLAUDE.md exceeds ~40k characters, or the user asks to distill, shorten, trim, or shrink CLAUDE.md."
---

# Distill

CLAUDE.md is loaded into every session's context. Past ~40k characters it crowds out the work. This skill distills it down — same meaning, less text — and uses past Claude Code transcripts as evidence for what's actually load-bearing.

The contract — `## Test Trees` — is sacred. Distillation never paraphrases or "tightens" a tree. Everything else is negotiable.

CLAUDE.md is the source of intent that drives tests and code, so it will necessarily restate things that also appear in code. That overlap is not redundancy — do not cut content just because the code "already shows" it.

## When to Use

- CLAUDE.md exceeds ~40k characters
- The user asks to distill, shorten, trim, or shrink CLAUDE.md

## Inviolable Rules

1. **Never modify test trees.** Every line under `## Test Trees` stays byte-for-byte identical. If a tree looks stale, ask the user — do not edit it unilaterally. Same rule the stop hook enforces.
2. **Never drop a capability the code still has.** If something CLAUDE.md mentions still exists in code, the information must survive — kept, or moved to a referenced file with a pointer left behind.
3. **Always confirm before writing.** Show the plan, get explicit approval. No silent edits.
4. **Never restructure `MENTAL_MODEL.md`; curate within it.** Keep the seven H2 sections intact — no merging, no new sections, no moving content across them. Within each section, choose what earns its place; displace low-value lines rather than compressing more in. The goal is value density, not volume.

## Process

### 1. MEASURE

Read `CLAUDE.md`. Report current size in characters and lines. If under 40k and the user didn't explicitly ask, stop.

### 2. FIRST PASS: TIGHTEN EVERYTHING

Before any cuts, rewrite every non-test-tree sentence for maximum concision. Strip filler, collapse repetition, replace prose lists with bullet lists, prefer one strong sentence over three weak ones. This pass alone often gets the file under budget. Re-measure.

### 3. IF STILL OVER BUDGET: GATHER EVIDENCE

The remaining content is all plausibly useful. To rank it, look at what past sessions actually needed. Claude Code transcripts live in `~/.claude/projects/<project-slug>/*.jsonl`. Find the slug for the current project, then scan recent transcripts for signal:

- **User corrections** — messages where the user pushed back, said "no", "don't", "stop", or restated a rule. The CLAUDE.md content this would have prevented is high-value — keep it.
- **Repeated mistakes** — the same wrong assumption made across multiple sessions. The CLAUDE.md content that would have prevented it is high-value — keep it, possibly strengthen it.
- **Doc reads** — Read tool calls against CLAUDE.md or files in the repo map. Sections that get read often are load-bearing. Sections that never get referenced in any transcript are candidates to move out.
- **Tool-call patterns** — what files Claude reaches for first when starting a task. Repo Map entries pointing to those files are high-value; entries pointing to files nothing ever touches are candidates to move.

Summarise the evidence: per section (or per bullet), high / medium / low based on observed need.

### 4. CLASSIFY

Using the evidence:

- **Keep verbatim** — `## Test Trees`. Always.
- **Keep tightened** — high-evidence content, in its already-tightened form.
- **Move to a referenced file** — medium and low-evidence content that's still useful. Move to a sibling file (e.g. `docs/<topic>.md`), leave a one-line pointer in CLAUDE.md.
- **Flag as possibly stale** — content for capabilities that may no longer exist. Never auto-removed. Hand to the user as a question.

### 5. PRESENT THE PLAN

Show the user:

- Original size → after-tighten size → projected final size
- Per-section: kept, tightened, moved, with the evidence that drove the call
- Any flagged stale content, with the question: update, remove, or leave?
- New files that will be created

Wait for approval. Revise and re-present if needed.

### 6. APPLY

Make the edits. Create any new files. Diff test trees after to confirm they're byte-identical.

### 7. VERIFY

- Re-read the new `CLAUDE.md` end to end
- Confirm every tree under `## Test Trees` is unchanged
- Confirm nothing the code still does has been silently dropped
- Report final size

## What Done Looks Like

1. CLAUDE.md is meaningfully smaller (typically under 30k characters)
2. Every test tree is byte-identical to before
3. Cuts are justified by transcript evidence, not guesswork
4. Anything moved is reachable via a one-line pointer
5. The user has explicitly approved every cut and move
