load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'

PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# A bare `[[ ]]`/`[ ]` assertion that isn't the LAST statement in a @test body
# can fail without failing the test: bash suppresses errexit for a whole
# function once that function's own exit status is used as a condition (which
# is how bats invokes every test). Use assert_output/refute_output (loaded
# above) for checks against `$output`; for anything else, append `|| return 1`.

# Scope: bats covers scripted logic in `hooks/` and bats-only utilities in
# `scripts/`, plus a System-layer check that each `SKILL.md`'s prose actually
# contains the instructions its tree promises (grep, not execution — mirrors
# a system tree's leaves against the file that governs the skill). Whether
# Claude actually follows a `SKILL.md` under the model is a distinct claim,
# covered only in `test/journey/`. The two layers are complementary, not
# redundant: a prose check catches a skill file losing an instruction; a
# journey case catches the model ignoring an instruction that's still there.
