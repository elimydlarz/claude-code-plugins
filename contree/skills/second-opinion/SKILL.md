---
name: second-opinion
description: "Get an independent review of completed work from a different model — sends the change and the test-tree contract to Z.AI's GLM 5.2 with ZAI_API_KEY, or to DeepSeek with DEEPSEEK_API_KEY, and surfaces its critique. TRIGGER when: sync has just finished, the user asks for a second opinion, an independent review, or a sanity check on completed work before a PR or release."
---

# Second Opinion

Sends the completed change to a **different model** — Z.AI's **GLM 5.2** when `ZAI_API_KEY` is present, or **DeepSeek** when `DEEPSEEK_API_KEY` is present — and surfaces its independent review. Once `sync` reports the trees and implementation are aligned, a second pair of eyes from another model catches what a single perspective misses: bugs, drift from the test-tree contract, rule violations, gaps the author rationalised away.

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

Call Z.AI's chat completions API with the `glm-5.2` model when `ZAI_API_KEY` is present. When `ZAI_API_KEY` is absent and `DEEPSEEK_API_KEY` is present, call DeepSeek's chat completions API with `deepseek-chat`. Send the change and the test trees, and ask the model to review the work as an independent critic: does the change satisfy the test-tree contract, are there bugs or drift, does it honour the rules (KISS, YAGNI, no fake code, fail-fast, no comments), and what would it change?

```bash
REVIEW_INPUT=$(printf 'TEST TREES (the contract):\n\n%s\n\nCHANGE (the work to review):\n\n%s\n' \
  "$(cat TEST_TREES.md)" "$CHANGE")
if [ -n "${ZAI_API_KEY:-}" ]; then
  REVIEW_API_KEY="$ZAI_API_KEY"
  REVIEW_BASE_URL="${ZAI_BASE_URL:-https://api.z.ai/api/paas/v4}"
  REVIEW_MODEL="glm-5.2"
else
  REVIEW_API_KEY="${DEEPSEEK_API_KEY:?missing both ZAI_API_KEY and DEEPSEEK_API_KEY}"
  REVIEW_BASE_URL="${DEEPSEEK_BASE_URL:-https://api.deepseek.com/v1}"
  REVIEW_MODEL="deepseek-chat"
fi

curl -sS -f -X POST "$REVIEW_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $REVIEW_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg input "$REVIEW_INPUT" --arg model "$REVIEW_MODEL" '{
        model: $model,
        messages: [
          { role: "system", content: "You are an independent code reviewer. Review the completed work against the test-tree contract. Review database schema changes, API contract changes, and impacts on other systems. Surface bugs, drift from the trees, rule violations, and gaps. Be specific and concrete." },
          { role: "user", content: $input }
        ]
      }')" \
  | jq -r '.choices[0].message.content'
```

### 3. Surface the review

Present the returned review to the user verbatim, attributed to `$REVIEW_MODEL` so it is clear this is a second opinion from another model, not your own. The user decides what to act on; where the review finds drift or gaps, route them back through `change`, `sync`, or `tdd`.

## Failure is loud

If the review request fails — missing both `ZAI_API_KEY` and `DEEPSEEK_API_KEY`, an API error, a non-2xx response (`curl -f`), or empty content — surface the failure as an error and stop. Never fabricate a review, summarise the diff yourself and pass it off as the independent model's review, or report a second opinion you did not get. A missing review is an honest outcome; a fake one is not.
