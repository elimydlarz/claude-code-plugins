---
name: second-opinion
description: "Get an independent review of completed work from OpenAI's gpt-5.6-sol with high reasoning effort — sends the work and test-tree contract through the Responses API with OPENAI_API_KEY and surfaces its critique. TRIGGER when: sync has just finished, the user asks for a second opinion, an independent review, or a sanity check on completed work before a PR or release."
---

# Second Opinion

Sends the completed work to OpenAI's **gpt-5.6-sol** with high reasoning effort and surfaces its independent review. Once `sync` reports the trees and implementation are aligned, a second pair of eyes catches what a single perspective misses: bugs, drift from the test-tree contract, rule violations, gaps the author rationalised away.

## When to Use

- Immediately after `sync` reports the project is in sync — the natural next step.
- Before a PR or release, as a final independent check on completed work.
- When the user asks for a second opinion, an independent review, or a sanity check.

## Process

### 1. Gather the work to review

Work out *what* to review before gathering it. Rely on natural language, not on a fixed git boundary:

- **If the user gave a natural-language indication** of what to review — "the second-opinion change", "the last thing we did", "everything since the refactor" — review exactly that.
- **Absent a clear indication**, review the **last non-trivial, naturally grouped change**. Do not equate the work with a single commit: **trunk-sync** commits continuously, so one logical change is smeared across many tiny auto-commits and the latest commit is rarely the whole story. Do not limit yourself to the working tree either — it is often empty once trunk-sync has committed. Read the recent history and the working tree together, skip trivial commits (version bumps, formatting, the sync's own noise), and assemble the most recent coherent unit of work.

Gather that change as a diff. For the working tree plus any new untracked files (the common case):

```bash
CHANGE=$(git diff HEAD; git ls-files --others --exclude-standard | while read -r f; do git diff --no-index -- /dev/null "$f" || true; done)
```

For a wider grouping spanning several trunk-sync commits, diff the appropriate range instead. Then read `## Test Trees` (or `TEST_TREES.md`) — this is the contract the work must satisfy. If there are no non-trivial changes to review, say so and stop — there is nothing to review.

### 2. Ask an independent model to review against the contract

Call OpenAI's Responses API at `https://api.openai.com/v1/responses` with `OPENAI_API_KEY`, the `gpt-5.6-sol` model, and high reasoning effort. Send the work and the test trees, and ask the model to review the work as an independent critic: does the change satisfy the test-tree contract, are there bugs or drift, does it honour the rules (KISS, YAGNI, no fake code, fail-fast, no comments), what database schema or API contract changes does it introduce, what does it impact in other systems, and what would it change?

```bash
REVIEW_INPUT=$(printf 'TEST TREES (the contract):\n\n%s\n\nCHANGE (the work to review):\n\n%s\n' \
  "$(cat TEST_TREES.md)" "$CHANGE")
REVIEW_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
REVIEW_MODEL="gpt-5.6-sol"

REVIEW_RESPONSE=$(curl -sS -f -X POST "$REVIEW_BASE_URL/responses" \
  -H "Authorization: Bearer ${OPENAI_API_KEY:?OPENAI_API_KEY is required}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg input "$REVIEW_INPUT" --arg model "$REVIEW_MODEL" '{
        model: $model,
        reasoning: { effort: "high" },
        instructions: "You are an independent code reviewer. Review the completed work against the test-tree contract. Review database schema changes, API contract changes, and impacts on other systems. Surface bugs, drift from the trees, rule violations, and gaps. Be specific and concrete.",
        input: $input
      }')")
REVIEW=$(printf '%s' "$REVIEW_RESPONSE" | jq -er '[.output[]? | select(.type == "message") | .content[]? | select(.type == "output_text") | .text] | join("\n") | select(length > 0)')
printf '%s\n' "$REVIEW"
```

### 3. Surface the review

Present the returned review to the user verbatim, attributed to `gpt-5.6-sol` so it is clear this is a second opinion, not your own. The user decides what to act on; where the review finds drift or gaps, route them back through `change`, `sync`, or `tdd`.

## Failure is loud

If the review request fails — `OPENAI_API_KEY` is missing, the API returns an error or non-2xx response (`curl -f`), or the response contains no review (`jq -e`) — surface the failure as an error and stop. Never fabricate a review, summarise the diff yourself and pass it off as the independent model's review, or report a second opinion you did not get. A missing review is an honest outcome; a fake one is not.
