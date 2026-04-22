# CLAUDE.md

## What This Is

A Claude Code plugin that unifies test-tree-driven development with living requirements. Test trees ARE the requirements — they live in `TEST_TREES.md` at the project root, describe what the system does using EARS syntax, and are kept in sync with implementation automatically.

Mechanisms:

- **Directions** — skill routing printed by the SessionStart hook. Names each skill (`change`, `tdd`, `sync`, `setup`, `workflow`) with a one-line trigger so the agent reaches for skills eagerly rather than relying on skill-frontmatter discovery alone. Lives inline in `hooks/session-start.sh`.
- **Rules** — coding principles printed by the SessionStart hook (simplicity, expressiveness, fail-fast, no fake code, etc.). The rules list lives inline in `hooks/session-start.sh` so it ships with the plugin install.
- **setup skill** — prepare the project for ongoing test-tree-driven development. Configures test framework with tree reporters, generates initial test trees, establishes the contract.
- **change skill** — set expected behaviour. Talks through the change, writes or modifies test trees before code exists.
- **sync skill** — identify gaps and cruft. Compares test trees against implementation in both directions — surfaces drift, staleness, and missing coverage.
- **tdd skill** — close gaps. Outside-in TDD where every test traces back to a test tree — one failing test at a time until the contract is fulfilled.
- **workflow skill** — the full arc. Runs `change` → `sync` → `tdd` end to end — from idea to verified working software.
- **Stop hook** — guard the contract. Fires after every response, detecting drift between intent and implementation. Yields the turn silently when the response ends with a question, so questions to the user aren't buried under drift-check output.
- **Mental-model validator (PostToolUse)** — after any tool call that edits MENTAL_MODEL.md, `hooks/post-update-check.sh` runs `hooks/validate-mental-model.sh` and surfaces its advisory findings (missing sections, rogue headings, cap overflow) via additionalContext JSON.
- **Pressure phrase** — inject motivation. The SessionStart hook prints one random pressure phrase (tip-framing, career-stakes, boss-watching, or urgency) alongside the rules, so the agent starts every session under a little stage-light.
- **Self-care hook** — nudge the user. Fires on each `UserPromptSubmit` in any session; records a shared heartbeat and, after 20 minutes of continuous interaction (no gap longer than 5 minutes between heartbeats across any sessions), injects a 20-20-20 eye-break reminder into Claude's context via `additionalContext` so Claude opens its response with the nudge.

## Mental Model

Test trees are the living contract between intent and implementation — both the specification (in `TEST_TREES.md`) and the test structure (in code). They use EARS syntax to choose the right keyword for each requirement — `when` for events, `while` for state, `if/then` for errors, `where` for optional features, bare `then` for ubiquitous constraints. When one behaviour depends on another's outcome, it nests under that outcome (causal nesting) — not as a sibling. Contree prescribes **hexagonal architecture** with dependencies pointing inward and a strict linter (dependency-cruiser for JS/TS) enforcing the boundaries. Tests are layered by architectural seam: **Domain**, **Use-case**, **Adapter** (driving and driven), and **System**. Each driven port ships with an in-memory twin so Use-case and System tests run fast; a shared port contract suite is imported by both the in-memory adapter's test file and the real adapter's test file, making substitution sound. Every behavioural unit gets its own tree in `TEST_TREES.md`; every tree reifies exactly one test file. See `skills/tdd/SKILL.md` for the full framing. `change` sets expected behaviour. `sync` identifies where reality has drifted. `tdd` closes gaps. The stop hook guards the contract — drift is never resolved silently. Coding rules enforce principles (simplicity, expressiveness, fail-fast) across all work.

Flow: `setup` prepares the project for test-tree-driven development → `change` sets expected behaviour → `sync` identifies gaps and cruft → `tdd` closes gaps. Or use `workflow` for the full arc without pausing. The stop hook guards the contract throughout. The SessionStart hook bundles a pressure phrase with the rules to keep the agent sharp. The self-care hook nudges the user to take eye breaks via the 20-20-20 rule. Rules apply always.

## Repo Map

- `CLAUDE.md` — this file
- `TEST_TREES.md` — functional and cross-functional requirements as test trees (the authoritative behaviour contract)
- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `package.json` — dev dependencies (bats-support, bats-assert) and test scripts
- `hooks/hooks.json` — wires SessionStart (rules + pressure phrase), Stop (drift check), UserPromptSubmit (self-care), and PostToolUse (mental-model validator)
- `hooks/session-start.sh` — SessionStart hook: prints the skill Directions block, the inline rules list, and one random pressure phrase (sourced from `hooks/pressure-phrases.sh`) to stdout
- `hooks/pressure-phrases.sh` — pressure-phrase pool: prints one random phrase when run, exposes `pressure_phrases` array when sourced
- `hooks/stop-drift-check.sh` — Stop hook: injects drift-check prompt unless Claude's last response ends with a question, in which case it yields the turn to the user
- `hooks/self-care-20-20-20.sh` — UserPromptSubmit hook: reminds user of the 20-20-20 rule after 20 min of keyboard time
- `hooks/post-update-check.sh` — PostToolUse hook: when MENTAL_MODEL.md is edited, runs `validate-mental-model.sh` and surfaces findings to Claude via additionalContext JSON
- `hooks/validate-mental-model.sh` — advisory validator: checks MENTAL_MODEL.md for the seven named sections, section caps, rogue headings, and file presence
- `rules/integration-testing.md` — standalone integration-testing rules (not a skill)
- `scripts/validate-skill-frontmatter.sh` — bats-only utility: asserts every `skills/*/SKILL.md` has non-empty `name` and `description`
- `skills/setup/SKILL.md` — prepare the project for test-tree-driven development: framework, reporters, initial trees
- `skills/change/SKILL.md` — set expected behaviour: write or modify test trees before code exists
- `skills/sync/SKILL.md` — identify gaps and cruft: test trees vs implementation in both directions
- `skills/tdd/SKILL.md` — close gaps: outside-in TDD, one failing test at a time
- `skills/workflow/SKILL.md` — the full arc: idea → contract → verified implementation
- `test/plugin.bats` — structural tests: plugin manifest, skill files, frontmatter, hook wiring
- `test/pre-task-hook.bats` — SessionStart hook tests: rules, Directions, mental-model and test-tree framing, file interpolation, pressure phrase
- `test/post-task-hook.bats` — Stop hook tests: loop prevention, exit codes, question-mark yielding, nudge content
- `test/post-update-hook.bats` — PostToolUse hook tests: validator runs only on MENTAL_MODEL.md edits, findings surface via additionalContext
- `test/mental-model-validator.bats` — validator tests: seven-section enforcement, cap overflow, rogue-heading flagging, missing-file flagging
- `test/pressure-phrases.bats` — pool tests: minimum size, randomness, register coverage, source-vs-run behaviour
- `test/self-care.bats` — self-care hook tests: heartbeat pruning, 20-minute continuity, reminder throttling, silent failure
- `test/validate-skill-frontmatter.bats` — frontmatter validator tests
- `test/functional/Dockerfile` — Docker image for functional tests (node + git + jq + claude CLI, fixture deps pre-installed)
- `test/functional/docker-run.sh` — runs functional tests in Docker (parallel), passes secrets via env vars
- `test/functional/docker-entrypoint.sh` — named functional test cases (`full-workflow`, `layered-workflow`, `mental-model-validator-smoke`, `describe-it-drift`); each writes a transcript and a VERIFY prompt that evaluates the trees
- `test/fixtures/greenfield/` — empty JS project used as the starting state for `full-workflow`
- `test/fixtures/bookmarks-api/` — HTTP API fixture for `layered-workflow` (exercises all four hex layers + ports)
- `test/fixtures/ears-project/` — media player module for EARS pattern functional test
- `test/fixtures/seed-project/` — tiny JS counter module used as a legacy test target
- `test/fixtures/incidental-pass/` — counter with reset() pre-implemented (for incidental-pass scenarios)
- `test/fixtures/sync-drift/` — counter with deliberate drift (amount param without tree, decrement tree without impl)
- `test/fixtures/tdd-ready/` — counter with vitest configured + requirements, no tests

## Functional Testing

Run functional tests with `pnpm test:functional` (all) or `bash test/functional/docker-run.sh <test-name>` (one). After the script finishes, it prints the exact transcript file paths. **Always read the transcripts and evaluate each against the VERIFY criteria in docker-entrypoint.sh.** Report PASS/FAIL per criterion with evidence.

## Test Trees

See [TEST_TREES.md](TEST_TREES.md) — the definition of functional and cross-functional requirements.

## Dependencies

The stop hook requires `jq` on the host system.
