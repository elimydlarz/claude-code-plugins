#!/usr/bin/env bash
# SessionStart hook: print rules to stdout.
# Claude Code injects SessionStart stdout (exit 0) into the model's context.

cat <<'EOF'
# Directions

Use Contree skills as directed by their frontmatter: **setup-test-feedback**, **setup-linter**, **setup-architecture-linter**, **fix-architecture**, **setup-mental-model**, **setup-test-trees**, **bootstrap-test-trees**, **setup-mutation-testing**, **setup**, **change**, **tdd**, **sync**, **change-without-me**.

# Rules

- **Explicit and expressive** — name for what things do, not how they're implemented
- **KISS** — complexity is bad; simplicity above almost all else
- **YAGNI** — don't future-proof; implement only what you need now
- **Subtract, don't add** — can this be achieved by simplification instead?
- **Fail fast** — don't swallow errors; let the system fail when unexpected things happen
- **Resolve uncertainty** — look directly and remove optionality; don't hedge with fallbacks
- **Avoid nullability** — make things required; don't program defensively
- **Avoid indirection** — direct is better than conforming to arbitrary patterns
- **No fake code** — no skeletons, placeholders, or temporary implementations that pretend behaviour works. During TDD extraction, a new unit may begin as a stub that throws `NotImplemented`; that loud failure immediately drives the TDD loop for the unit.
- **Typing** — type everything; no `any`
- **No comments** — descriptive tests and expressive code obviate comments; comments bias agents against change, but trees and tests make the contract explicit so code can change radically. Never pollute the codebase with comments, fallbacks, or excuses — set expectations in test trees, enforce them in tests, express them in code.
- **Composition over inheritance** — no `extends`; use hooks, functional utilities, component composition
- **Read docs** — use Context7 for latest docs before using any library; don't guess API usage
- **Consumer-driven** — implement only what a consumer already needs
- **Hexagonal** — domain pure; I/O in adapters; dependencies point inward; each driven port ships with an in-memory twin. Any mock or stub outside that twin must carry a visible marker naming the reason — silent mocking is never acceptable
- **Decide, don't ask** — an obvious question is yours to answer, not the user's. Run the ladder before asking: consult these rules and the mental model first; if they don't settle it, use your own best judgment from the code in front of you; only escalate a consequential, genuinely under-determined choice that neither resolves.
- **Act, don't ask** — if your reasoning or response already includes the right answer, act on it rather than externalising the decision
- **Don't manufacture flags** — apply the same ladder to anything you'd flag, caveat, or surface "just in case": fix it if these rules or the mental model direct it; otherwise use your judgment; if neither makes it matter, stay silent rather than reporting it.
- **Retry at the source** — the layer closest to the failure retries; every layer above derives its timeout from that layer's worst case and does not retry the same failure class
- **Trees are the contract** — every observable behaviour and side effect belongs in `TEST_TREES.md`; every tree maps to one test file; every test file's describe/it hierarchy mirrors its tree verbatim.
- **Test kinds**
  - Journey: broad, production-like test of a curated user arc across capabilities, with external services replaced by test doubles only if unavoidable.
  - Component: deep in-process test of one capability through the whole app, with external services replaced by test doubles.
  - Integration: when concerned integration of some (but not all) pieces, test from the highest-level subject and mock everything except the subjects you are integrating to see if they really work together as expected
  - Unit: test of one public surface on one subject; every public surface gets native unit tests, and every dependency outside the subject is mocked.
- **Outside-in TDD** — start from the behaviour in the current tree and its consumer. Write a test, observe RED, implement GREEN, then during REFACTOR notice too much branching in the test or tree. Extract some branching into a new unit with a mock and a stub that throws `NotImplemented`. The mock makes the consumer tests pass; the stub makes running code fail loudly. That is the signal to repeat the TDD process from step 1 for the new unit.
- **Debugging means a test gap** — if you're debugging, the tests weren't good enough. Before fixing, find the tree path that should have caught the bug (add it if it's missing), write the failing test, then fix the code.
- **Behaviour, not internals** — every tree describes what crosses its level's interface (inputs, outputs, side-effects). Never the implementation inside. Journey/System/Adapter speak the consumer's vocabulary; Domain/Use-case/Port-contract speak the unit's own functions, types, and errors — both only as observable at the seam.
- **No env-var behaviour switches** — do not use environment variables to vary behaviour between test and runtime
EOF

if [ -f MENTAL_MODEL.md ]; then
  printf '\n# Mental Model\n\n'
  cat MENTAL_MODEL.md
fi

if [ -f TEST_TREES.md ]; then
  printf '\n# Test Trees\n\n'
  cat TEST_TREES.md
fi

cat <<'EOF'

# Working with the Mental Model and Test Trees

- Use the mental model's existing concepts, vocabulary, and decisions rather than inventing parallel ones.
- Preserve the mental model's invariants. If a task appears to require breaking one, surface the conflict rather than routing around it.
- If the mental model is wrong, incomplete, or misleading for this task, flag it rather than silently reshaping it through code.
- Treat test trees as the authoritative behaviour contract — do not diverge from them silently.
EOF

exit 0
