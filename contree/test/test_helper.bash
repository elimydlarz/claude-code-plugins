load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'

PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Scope: bats covers scripted logic in `hooks/` and bats-only utilities in
# `scripts/`. Skill behaviour under the model — whether Claude follows a
# `SKILL.md` — is covered only in `test/functional/`. Do not grep `SKILL.md`
# prose here; ${CLAUDE_PLUGIN_ROOT} is not reliably available in Bash calls
# issued from skills, so mechanical extraction into skill-adjacent scripts is
# not supported. Add a functional case instead.
