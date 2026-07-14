load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'

PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# A bare `[[ ]]`/`[ ]` assertion that isn't the LAST statement in a @test body
# can fail without failing the test: bash suppresses errexit for a whole
# function once that function's own exit status is used as a condition (which
# is how bats invokes every test). Use assert_output/refute_output (loaded
# above) for checks against `$output`; for anything else, append `|| return 1`.

# Scope: Bats covers scripted logic in `hooks/` and Bats-only utilities in
# `scripts/`, plus structural checks that each `SKILL.md` contains the
# instructions its tree promises. Whether a coding agent follows a `SKILL.md`
# under the model is a distinct production-like claim covered in `test/journey/`.
