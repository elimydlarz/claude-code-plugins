# Claude Code Integration Surface

This file records what this repo relies on when its plugins run under Claude Code.
It is intentionally about the agent/plugin boundary, not plugin business logic.

## Plugin Packaging

- Claude Code plugins use `.claude-plugin/plugin.json`.
- The repo root publishes a marketplace at `.claude-plugin/marketplace.json`.
- Users add the marketplace with:

```sh
claude plugin marketplace add elimydlarz/claude-code-plugins
```

- Plugin entries use repo-relative `source` paths, for example `./contree` and `./trunk-sync`.
- Contree and trunk-sync keep plugin manifests versioned with their package/release flow so installed marketplace plugins match the source that shipped.

## Hook Configuration

- Claude Code reads plugin hook configuration from `hooks/hooks.json`.
- Contree uses shared hook scripts for:
  - `SessionStart`
  - `UserPromptSubmit`
  - `PostToolUse`
  - `Stop`
- Claude Code expands `CLAUDE_PLUGIN_ROOT` for plugin hook commands. Shared scripts resolve plugin-relative files through that variable.
- Hook commands in this repo are written as shell commands, usually `bash "${CLAUDE_PLUGIN_ROOT}/..."`.

## Hook Input

- Claude Code `PostToolUse` edit hooks provide a Claude-shaped payload with `tool_input.file_path`.
- Contree's post-update hook uses that path to decide whether `MENTAL_MODEL.md` was edited.
- Claude Code Stop hook stdin provides `transcript_path`.
- Claude Code project-root-aware hooks can use `CLAUDE_PROJECT_DIR`.

## Hook Output

- Claude Code hook scripts can inject context with JSON shaped as:

```json
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"..."}}
```

- Contree uses that channel for the mental-model validator and the self-care reminder.
- Contree's Stop hook writes blocking guidance to stderr and exits 2 to force a follow-up turn when drift checks or question-stop checks need attention.
- SessionStart stdout is used as startup context for rules, directions, mental model, and test trees.

## Functional Harness Notes

- Contree's Claude functional journeys call `claude -p` with:
  - `--plugin-dir "$CONTREE_ROOT"`
  - `--dangerously-skip-permissions`
  - `--output-format stream-json`
  - `--verbose`
- Multi-phase journeys continue the same Claude conversation with `-c`.
- The functional harness writes `<test>-claude-transcript.jsonl` and `<test>-claude-verify.txt`.
- Hook runner failures are treated as functional failures by scanning transcripts for phrases such as `hook exited with code`, `command not found`, missing executables, and `exec: ... not found`.

