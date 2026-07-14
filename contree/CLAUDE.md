# CLAUDE.md

Note: This is project publishes the Contree harness. It's important to understand when we are making changes to how this project works vs when we are making changes that will impact downstream operators of this harness. I refer to changes to this project as project changes and changes that will impact downstream operators of the harness changes.

## What This Is

A plugin that unifies test-tree-driven development with living requirements. Test trees ARE the requirements — they live in `TEST_TREES.md` at the project root, describe what the system does using EARS syntax, and are kept in sync with implementation automatically.

Ships under two harnesses from the same `skills/` and `hooks/` directories:

- **Claude Code** — `.claude-plugin/plugin.json` + `hooks/hooks.json`.
- **Codex CLI** — `.codex-plugin/plugin.json` declaring `"hooks": "./hooks/hooks.json"`. Codex injects `CLAUDE_PLUGIN_ROOT` (and `PLUGIN_ROOT`) into hook command env, so the shared hook scripts can run from the same plugin root. SessionStart plain stdout becomes `additionalContext`. Stop hook stdin includes `transcript_path` (same shape as Claude). **Codex requires hooks enabled in `~/.codex/config.toml`** — the journey harness enables both `[features].hooks = true` and `[features].plugin_hooks = true`. `codex exec --json` omits injected hook-context messages, so the journey harness appends Codex's internal session transcript for assertions. Net: the same scripts enforce the same contract across both harnesses.

Mechanisms:

- **Directions** — skill routing printed by the SessionStart hook. Names each skill (`change`, `tdd`, `sync`, `setup`, `change-without-me`) with a one-line trigger so the agent reaches for skills eagerly rather than relying on skill-frontmatter discovery alone. Lives inline in `hooks/session-start.sh`.
- **Rules** — coding principles printed by the SessionStart hook (simplicity, expressiveness, fail-fast, no fake code, etc.). The rules list lives inline in `hooks/session-start.sh` so it ships with the plugin install.
- **focused setup skills** — independently install and verify test feedback, conventional lint, architecture lint and repair, mental-model steering, test-tree steering, test-tree bootstrap, and mutation feedback. Each expands durable project-local hooks and fixes the feedback it establishes; bootstrap composes mental-model and tree setup before its separate test-implementation wave.
- **setup skill** — dynamically orchestrates the comprehensive operator-guided setup suite, using subagents for independent work and completing only after every configured feedback loop passes.
- **change skill** — set expected behaviour. Talks through the change, writes or modifies test trees before code exists.
- **sync skill** — identify gaps and cruft. Compares test trees against implementation in both directions — surfaces drift, staleness, and missing coverage.
- **tdd skill** — close gaps. Outside-in TDD where every test traces back to a test tree — one failing test at a time until the contract is fulfilled.
- **change-without-me skill** — the full arc. Runs `change` → `sync` → `tdd` → `second-opinion` end to end — from idea to verified, independently reviewed working software.
- **second-opinion skill** — review completed work with OpenAI's gpt-5.6-sol at high reasoning effort. Determines what to review from natural language, defaulting to the current worktree with untracked files included; sends it plus the test-tree contract through the Responses API with `OPENAI_API_KEY`; reviews database schemas, API contracts, impacts on other systems, and contract compliance; surfaces its independent review; and fails loudly rather than fabricating one. `sync` suggests it once the project is in sync.
- **diff-for-humans skill** — user-invoked (`/contree:diff-for-humans`). Generates one image explaining the change to a human — determined from natural language, or absent a clear indication the last non-trivial, naturally grouped change (not a single commit; not only the working tree; new untracked files included) — via OpenAI's gpt-image-2 model (images generations API, `OPENAI_API_KEY`), choosing what to depict from the nature of the change, its technical substance (contracts, databases, behaviour, test trees), its key details, and its audience; surfaces those choices for review; fails loudly rather than fabricating an image. Not hook-triggered.
- **Stop hook** — guard the contract. Fires after every response, detecting drift between intent and implementation. The `stop_hook_active` guard prevents the hook from drift-checking its own drift-check turn.

## Mental Model

The mental model lives in [MENTAL_MODEL.md](./MENTAL_MODEL.md) — Core Domain Identity, World-to-Code Mapping, Ubiquitous Language, Bounded Contexts, Invariants, Decision Rationale, and Temporal View. It defines the four test kinds and the outside-in flow: RED, GREEN, then REFACTOR excessive branching behind a mock and `NotImplemented` stub; passing consumer tests plus the throwing stub signal a new TDD cycle for that unit.

Flow: `setup` prepares the project for test-tree-driven development → `change` sets expected behaviour → `sync` identifies gaps and cruft → `tdd` closes gaps → `second-opinion` gets an independent review of the completed work from a different model. Or use `change-without-me` for the full arc without pausing. The stop hook guards the contract throughout. Rules apply always.

## Repo Map

- `CLAUDE.md` — this file
- `TEST_TREES.md` — functional and cross-functional requirements as test trees (the authoritative behaviour contract)
- `.claude-plugin/plugin.json` — Claude Code plugin manifest (name, version, description)
- `.codex-plugin/plugin.json` — Codex CLI plugin manifest (skills + hooks; mirrors Claude version, bumped together by `publish-contree.sh`)
- `package.json` — dev dependencies (bats-support, bats-assert) and test scripts
- `hooks/hooks.json` — wires SessionStart (rules) and Stop (drift check)
- `hooks/session-start.sh` — SessionStart hook: prints the skill Directions block and the inline rules list to stdout
- `hooks/stop-drift-check.sh` — Stop hook: injects the drift-check prompt after each response
- `website/index.html` — self-contained explainer site (no build step) pitching contree to developers new to TDD: bridges from test-first to test-trees, living requirements, the four test kinds, hexagonal architecture, the workflow, and the Claude Code hook mechanics (SessionStart and Stop). Published to GitHub Pages at https://elimydlarz.github.io/claude-code-plugins/contree/ by the repo-root `.github/workflows/pages.yml` workflow, which stages `contree/website/` into `_site/contree/` (one subdir per plugin, so other plugins can add their own pages) and deploys on push to main
- `scripts/validate-skill-frontmatter.sh` — bats-only utility: asserts every `skills/*/SKILL.md` has non-empty `name` and `description`
- `skills/setup-test-feedback/SKILL.md` — normal, journey, and impact-selected test feedback
- `skills/setup-linter/SKILL.md` — strong conventional lint, automatic repair, CI, and save-time feedback
- `skills/setup-architecture-linter/SKILL.md` — architecture rules, combined lint, CI, and Stop feedback
- `skills/fix-architecture/SKILL.md` — subagent-partitioned architecture repair until every rule passes
- `skills/setup-mental-model/SKILL.md` — operator-reconciled seven-section model plus project-local SessionStart and Stop steering
- `skills/setup-test-trees/SKILL.md` — operator-reconciled consumer-driven EARS contract plus project-local SessionStart and Stop steering
- `skills/bootstrap-test-trees/SKILL.md` — composes both steering skills, then runs the required test-implementation wave
- `skills/setup-mutation-testing/SKILL.md` — full mutation gate, relevant-change incremental Stop feedback, and test strengthening to the agreed threshold
- `skills/setup/SKILL.md` — comprehensive dynamic orchestration of every focused setup skill
- `skills/change/SKILL.md` — set expected behaviour: write or modify test trees before code exists
- `skills/sync/SKILL.md` — identify gaps and cruft: test trees vs implementation in both directions
- `skills/tdd/SKILL.md` — close gaps: outside-in TDD, one failing test at a time
- `skills/change-without-me/SKILL.md` — the full arc: idea → contract → verified implementation → independent review
- `skills/second-opinion/SKILL.md` — review completed work: determine the work from natural language (else the current worktree, untracked files included), send it + test-tree contract to OpenAI gpt-5.6-sol at high reasoning effort (`OPENAI_API_KEY`), cover database schemas, API contracts, and impacts on other systems, surface its review, fail loudly
- `skills/diff-for-humans/SKILL.md` — user-invoked `/contree:diff-for-humans`: determine the change from natural language (else the last non-trivial, naturally grouped change, untracked files included), generate one image via OpenAI gpt-image-2; choose subject from nature/technical substance (contracts, databases, behaviour, test trees)/details/audience; surface choices; fail loudly
- `test/pre-task-hook.bats` — SessionStart hook tests: rules, Directions, mental-model and test-tree framing, file interpolation
- `test/post-task-hook.bats` — Stop hook tests: loop prevention, exit codes, transcript handling, nudge content
- `test/validate-skill-frontmatter.bats` — frontmatter validator tests
- `test/dual-harness-compatibility.bats` — dual-harness contract: both manifests, version lockstep, plugin.json fields, shared hooks.json, `$CLAUDE_PLUGIN_ROOT` invocation, Stop hook wiring, OpenAI Responses authentication, gpt-5.6-luna at medium reasoning effort, and fail-fast missing-key handling
- `test/journey/Dockerfile` — Docker image for the journey suite (node + git + jq + curl + claude CLI + codex CLI, fixture deps pre-installed); curl is required by the `diff-for-humans` and `second-opinion` skills' API recipes
- `test/journey/docker-run.sh` — runs `(test, harness)` pairs from MATRIX in Docker (parallel), sources `OPENAI_API_KEY` from `.env`, fails fast when it is absent, and passes it to both coding-agent harnesses
- `test/journey/docker-entrypoint.sh` — named journey cases (`setup`, `test-kinds-workflow`, `describe-it-drift`, `diff-images`, `second-opinion`) parameterised by harness (`claude` | `codex`); both harnesses run gpt-5.6-luna at medium reasoning effort through OpenAI's Responses API, with Claude routed through the harness-local Anthropic-to-Responses proxy and Codex configured directly; `setup` deterministically verifies project preparation, changed-test baseline and impact selection, visible failure output with exit 2, dual-harness hook configuration, and a real edit after project hooks load; `diff-images` stages a change, mocks the gpt-image-2 endpoint with a local stub via `OPENAI_BASE_URL`, and deterministically self-verifies (no AI eval, exits non-zero on failure) that `/contree:diff-for-humans` called the mocked gpt-image-2 endpoint and saved the returned image; `second-opinion` stages work, mocks OpenAI's Responses API via `OPENAI_BASE_URL`, and deterministically self-verifies (no AI eval, exits non-zero on failure) the gpt-5.6-sol model, high reasoning effort, review concerns, untracked work, and surfaced review; every run fails if the transcript contains hook runner errors; `second-opinion-live` (NOT in the auto MATRIX — billable, non-deterministic, run manually with a real `OPENAI_API_KEY`) plants a deliberate contract-violating bug and exercises a real gpt-5.6-sol call, extracting the review for manual judgement of whether the live model caught it; for Codex it pre-seeds the plugin cache under an isolated `CODEX_HOME`, enables hooks plus shell environment inheritance, and configures `wire_api = "responses"`; each run writes a `<test>-<harness>-transcript.jsonl` and `<test>-<harness>-verify.txt`
- `test/fixtures/greenfield/` — empty JS project used by setup and change-without-me tests
- `test/fixtures/setup-existing/` — prepared JS project used to verify setup merges the maintained changed-test runner and Stop hook into both Claude Code and Codex configuration
- `test/fixtures/bookmarks-api/` — HTTP API fixture for the outside-in workflow across Journey, Component, Integration, and Unit tests
- `test/fixtures/describe-it-drift/` — pre-seeded tree + test file whose describe/it deliberately does not mirror the tree (for the `describe-it-drift` journey case)

## Journey Testing

Run the journey suite with `pnpm test:journey` (all `(test, harness)` pairs in MATRIX), `bash test/journey/docker-run.sh <test-name>` (one, default claude harness), or `bash test/journey/docker-run.sh <test-name> codex` (explicit harness). After the script finishes, it prints the exact transcript file paths. **Always read the transcripts and evaluate each against the VERIFY criteria in docker-entrypoint.sh.** Report PASS/FAIL per criterion with evidence.

## Test Trees

See [TEST_TREES.md](TEST_TREES.md) — the definition of functional and cross-functional requirements.

## Dependencies

The stop hook requires `jq` on the host system.
