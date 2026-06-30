# CLAUDE.md

## What This Is

A plugin that unifies test-tree-driven development with living requirements. Test trees ARE the requirements — they live in `TEST_TREES.md` at the project root, describe what the system does using EARS syntax, and are kept in sync with implementation automatically.

Ships under two harnesses from the same `skills/` and `hooks/` directories:

- **Claude Code** — `.claude-plugin/plugin.json` + `hooks/hooks.json`.
- **Codex CLI** — `.codex-plugin/plugin.json` declaring `"hooks": "./hooks/hooks.json"`. Codex injects `CLAUDE_PLUGIN_ROOT` (and `PLUGIN_ROOT`) into hook command env, so the existing hook commands work verbatim. `apply_patch` is aliased to match the `Edit|Write|MultiEdit` PostToolUse matcher. SessionStart plain stdout becomes `additionalContext`. Stop hook stdin includes `transcript_path` (same shape as Claude). **Codex requires `[features] plugin_hooks = true` in `~/.codex/config.toml`** — the feature is `Stage::UnderDevelopment, default_enabled: false` in codex 0.128, so without opt-in `hooks.json` is ignored. Net (with the flag set): full enforcement on both harnesses from the same hook scripts and hooks.json.

Mechanisms:

- **Directions** — skill routing printed by the SessionStart hook. Names each skill (`change`, `tdd`, `sync`, `setup`, `workflow`) with a one-line trigger so the agent reaches for skills eagerly rather than relying on skill-frontmatter discovery alone. Lives inline in `hooks/session-start.sh`.
- **Rules** — coding principles printed by the SessionStart hook (simplicity, expressiveness, fail-fast, no fake code, etc.). The rules list lives inline in `hooks/session-start.sh` so it ships with the plugin install.
- **setup skill** — prepare the project for ongoing test-tree-driven development. Configures test framework with tree reporters, generates initial test trees, establishes the contract.
- **change skill** — set expected behaviour. Talks through the change, writes or modifies test trees before code exists.
- **sync skill** — identify gaps and cruft. Compares test trees against implementation in both directions — surfaces drift, staleness, and missing coverage.
- **tdd skill** — close gaps. Outside-in TDD where every test traces back to a test tree — one failing test at a time until the contract is fulfilled.
- **workflow skill** — the full arc. Runs `change` → `sync` → `tdd` → `second-opinion` end to end — from idea to verified, independently reviewed working software.
- **second-opinion skill** — review completed work with a different model. Determines what to review from natural language — or, absent a clear indication, the last non-trivial, naturally grouped change (not a single commit, since trunk-sync commits continuously; not only the working tree; new untracked files included) — sends it plus the test-tree contract to Z.AI's GLM 5.2 (chat completions API, `ZAI_API_KEY`) and surfaces its independent review; fails loudly rather than fabricating a review. `sync` suggests it once the project is in sync.
- **diff-for-humans skill** — user-invoked (`/contree:diff-for-humans`). Generates one image explaining the change to a human — determined from natural language, or absent a clear indication the last non-trivial, naturally grouped change (not a single commit; not only the working tree; new untracked files included) — via OpenAI's gpt-image-2 model (images generations API, `OPENAI_API_KEY`), choosing what to depict from the nature of the change, its technical substance (contracts, databases, behaviour, test trees), its key details, and its audience; surfaces those choices for review; fails loudly rather than fabricating an image. Not hook-triggered.
- **Stop hook** — guard the contract. Fires after every response, detecting drift between intent and implementation. Yields the turn silently when the response ends with a question, so questions to the user aren't buried under drift-check output.
- **Mental-model validator (PostToolUse)** — after any tool call that edits MENTAL_MODEL.md, `hooks/post-update-check.sh` runs `hooks/validate-mental-model.sh` and surfaces its advisory findings (missing sections, rogue headings, cap overflow) via additionalContext JSON.
- **Self-care hook** — nudge the user. Fires on each `UserPromptSubmit` in any session; records a shared heartbeat and, after 20 minutes of continuous interaction (no gap longer than 5 minutes between heartbeats across any sessions), injects a 20-20-20 eye-break reminder into Claude's context via `additionalContext` so Claude opens its response with the nudge.

## Mental Model

The mental model lives in [MENTAL_MODEL.md](./MENTAL_MODEL.md) — Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, and Temporal View. It is where the layered-testing model (Journey → System → Component → Adapter → Use-case → Domain), the outside-in flow, and the ground-level implementation gate are defined.

Flow: `setup` prepares the project for test-tree-driven development → `change` sets expected behaviour → `sync` identifies gaps and cruft → `tdd` closes gaps → `second-opinion` gets an independent review of the completed work from a different model. Or use `workflow` for the full arc without pausing. The stop hook guards the contract throughout. The self-care hook nudges the user to take eye breaks via the 20-20-20 rule. Rules apply always.

## Repo Map

- `CLAUDE.md` — this file
- `TEST_TREES.md` — functional and cross-functional requirements as test trees (the authoritative behaviour contract)
- `.claude-plugin/plugin.json` — Claude Code plugin manifest (name, version, description)
- `.codex-plugin/plugin.json` — Codex CLI plugin manifest (skills + hooks; mirrors Claude version, bumped together by `publish-contree.sh`)
- `package.json` — dev dependencies (bats-support, bats-assert) and test scripts
- `hooks/hooks.json` — wires SessionStart (rules), Stop (drift check), UserPromptSubmit (self-care), and PostToolUse (mental-model validator)
- `hooks/session-start.sh` — SessionStart hook: prints the skill Directions block and the inline rules list to stdout
- `hooks/stop-drift-check.sh` — Stop hook: injects drift-check prompt unless Claude's last response ends with a question, in which case it yields the turn to the user
- `hooks/self-care-20-20-20.sh` — UserPromptSubmit hook: reminds user of the 20-20-20 rule after 20 min of keyboard time
- `hooks/post-update-check.sh` — PostToolUse hook: when MENTAL_MODEL.md is edited, runs `validate-mental-model.sh` and surfaces findings to Claude via additionalContext JSON
- `hooks/validate-mental-model.sh` — advisory validator: checks MENTAL_MODEL.md for the seven named sections, section caps, rogue headings, and file presence
- `website/index.html` — self-contained explainer site (no build step) pitching contree to developers new to TDD: bridges from test-first to test-trees, living requirements, the layered architecture, the workflow, and the Claude Code hook mechanics (the four hooks, their stdout/stderr-exit-2/additionalContext injection channels, and the Stop-hook control flow). Published to GitHub Pages at https://elimydlarz.github.io/claude-code-plugins/contree/ by the repo-root `.github/workflows/pages.yml` workflow, which stages `contree/website/` into `_site/contree/` (one subdir per plugin, so other plugins can add their own pages) and deploys on push to main
- `rules/test-layers.md` — standalone test-layer rules (not a skill)
- `scripts/validate-skill-frontmatter.sh` — bats-only utility: asserts every `skills/*/SKILL.md` has non-empty `name` and `description`
- `skills/setup/SKILL.md` — prepare the project for test-tree-driven development: framework, reporters, initial trees
- `skills/change/SKILL.md` — set expected behaviour: write or modify test trees before code exists
- `skills/sync/SKILL.md` — identify gaps and cruft: test trees vs implementation in both directions
- `skills/tdd/SKILL.md` — close gaps: outside-in TDD, one failing test at a time
- `skills/workflow/SKILL.md` — the full arc: idea → contract → verified implementation → independent review
- `skills/second-opinion/SKILL.md` — review completed work: determine the change from natural language (else the last non-trivial, naturally grouped change, untracked files included), send it + test-tree contract to Z.AI GLM 5.2 (`ZAI_API_KEY`), surface its review, fail loudly
- `skills/diff-for-humans/SKILL.md` — user-invoked `/contree:diff-for-humans`: determine the change from natural language (else the last non-trivial, naturally grouped change, untracked files included), generate one image via OpenAI gpt-image-2; choose subject from nature/technical substance (contracts, databases, behaviour, test trees)/details/audience; surface choices; fail loudly
- `test/plugin.bats` — structural tests: plugin manifest, skill files, frontmatter, hook wiring
- `test/pre-task-hook.bats` — SessionStart hook tests: rules, Directions, mental-model and test-tree framing, file interpolation
- `test/post-task-hook.bats` — Stop hook tests: loop prevention, exit codes, question-mark yielding, nudge content
- `test/post-update-hook.bats` — PostToolUse hook tests: validator runs only on MENTAL_MODEL.md edits, findings surface via additionalContext
- `test/mental-model-validator.bats` — validator tests: seven-section enforcement, cap overflow, rogue-heading flagging, missing-file flagging
- `test/self-care.bats` — self-care hook tests: heartbeat pruning, 20-minute continuity, reminder throttling, silent failure
- `test/validate-skill-frontmatter.bats` — frontmatter validator tests
- `test/dual-harness-compatibility.bats` — dual-harness contract: both manifests, version lockstep, shared hooks.json, `$CLAUDE_PLUGIN_ROOT` invocation, PostToolUse matcher
- `test/journey/Dockerfile` — Docker image for the journey suite (node + git + jq + curl + claude CLI + codex CLI, fixture deps pre-installed); curl is required by the `diff-for-humans` and `second-opinion` skills' API recipes and their journey stubs' curl shims
- `test/journey/docker-run.sh` — runs `(test, harness)` pairs from MATRIX in Docker (parallel), passes ANTHROPIC_API_KEY (or the DeepSeek provider env, exported so `docker run -e` forwards it) + OPENAI_API_KEY + ZAI_API_KEY via env
- `test/journey/docker-entrypoint.sh` — named journey cases (`layered-workflow`, `mental-model-validator-smoke`, `describe-it-drift`, `diff-images`, `second-opinion`) parameterised by harness (`claude` | `codex`); `diff-images` (claude only) stages a change, mocks the gpt-image-2 endpoint with a local stub + curl shim, and deterministically self-verifies (no AI eval, exits non-zero on failure) that `/contree:diff-for-humans` called the mocked gpt-image-2 endpoint and saved the returned image; `second-opinion` (claude only) stages a change, mocks Z.AI's chat completions endpoint with a local stub + curl shim, and deterministically self-verifies (no AI eval, exits non-zero on failure) that `/contree:second-opinion` called the mocked GLM 5.2 endpoint and surfaced the returned review; `second-opinion-live` (claude only, NOT in the auto MATRIX — billable, non-deterministic, run manually with a real `ZAI_API_KEY`) plants a deliberate contract-violating bug and exercises a real GLM 5.2 call, extracting the review for manual judgement of whether the live model caught it; for codex pre-seeds `~/.agents/plugins/marketplace.json` + cache symlink + `~/.codex/config.toml` enable flag; each writes a `<test>-<harness>-transcript.jsonl` and `<test>-<harness>-verify.txt`
- `test/fixtures/greenfield/` — empty JS project (used by `mental-model-validator-smoke`)
- `test/fixtures/bookmarks-api/` — HTTP API fixture for `layered-workflow` (exercises every test layer, Journey down to Domain, + ports)
- `test/fixtures/describe-it-drift/` — pre-seeded tree + test file whose describe/it deliberately does not mirror the tree (for the `describe-it-drift` functional case)

## Functional Testing

Run functional tests with `pnpm test:functional` (all `(test, harness)` pairs in MATRIX), `bash test/functional/docker-run.sh <test-name>` (one, default claude harness), or `bash test/functional/docker-run.sh <test-name> codex` (explicit harness). After the script finishes, it prints the exact transcript file paths. **Always read the transcripts and evaluate each against the VERIFY criteria in docker-entrypoint.sh.** Report PASS/FAIL per criterion with evidence.

## Test Trees

See [TEST_TREES.md](TEST_TREES.md) — the definition of functional and cross-functional requirements.

## Dependencies

The stop hook requires `jq` on the host system.
