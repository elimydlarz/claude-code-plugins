#!/usr/bin/env bash
# SessionStart hook: print rules to stdout.
# Claude Code injects SessionStart stdout (exit 0) into the model's context.

cat <<'EOF'
# Directions

Eagerly use these skills to fulfil operator requests, where applicable:

- **change** — any behaviour change, before any code is discussed or written
- **tdd** — implementing behaviour, writing code, or writing tests
- **sync** — drift, gaps, staleness, or completeness
- **setup** — no test framework is configured or TEST_TREES.md is absent
- **workflow** — the full arc from idea to verified working software

# Rules

- **Decide, don't ask** — an obvious question is yours to answer, not the user's. Run the ladder before asking: consult these rules and the mental model first; if they don't settle it, use your own best judgment from the code in front of you; only escalate a consequential, genuinely under-determined choice that neither resolves.
- **Don't manufacture flags** — apply the same ladder to anything you'd flag, caveat, or surface "just in case": fix it if these rules or the mental model direct it; otherwise use your judgment; if neither makes it matter, stay silent rather than reporting it.
- **KISS** — complexity is bad; simplicity above almost all else
- **YAGNI** — don't future-proof; implement only what you need now
- **Subtract, don't add** — can this be achieved by simplification instead?
- **No fake code** — no skeletons, placeholders, or temporary implementations
- **Avoid indirection** — direct is better than conforming to arbitrary patterns
- **Data over control flow** — push variability into data so the hot path stays uniform. Replace "inspect state, branch, decide" with "do the thing to whatever's there." Conditionals that switch on history are a smell; the steady-state loop should do the same thing every tick.
- **Fail fast** — don't swallow errors; let the system fail when unexpected things happen
- **Retry at the source** — the layer closest to the failure retries; every layer above derives its timeout from that layer's worst case and does not retry the same failure class
- **Avoid nullability** — make things required; don't program defensively
- **Explicit and expressive** — name for what things do, not how they're implemented
- **No comments** — descriptive tests and expressive code obviate comments; comments bias agents against change, but trees and tests make the contract explicit so code can change radically. Never pollute the codebase with comments, fallbacks, or excuses — set expectations in test trees, enforce them in tests, express them in code.
- **Composition over inheritance** — no `extends`; use hooks, functional utilities, component composition
- **Typing** — type everything; no `any`
- **Z-index** — avoid z-index; good layout doesn't rely on it
- **Read docs** — use Context7 before using any library; don't guess API usage
- **Consumer-driven** — implement only what a consumer already needs
- **Resolve uncertainty** — look directly and remove optionality; don't hedge with fallbacks
- **Act, don't ask** — if your reasoning or response already includes the right answer, act on it rather than externalising the decision
- **pnpm** — use pnpm, not npm, for JS/TS
- **Trees are the contract** — every expected behaviour and side effect goes in `## Test Trees`; every tree is verified by a test; every test drives the real implementation. File writes, external calls, state mutations, and cleanup all count as behaviour — if it's observable anywhere (filesystem, network, logs, next invocation), it belongs in the tree. If you're wondering whether an expectation belongs in the trees, the answer is yes.
- **Behaviour, not internals** — every tree describes what crosses its level's interface (inputs, outputs, side-effects). Never the implementation inside. Journey/System/Adapter speak the consumer's vocabulary; Domain/Use-case/Port-contract speak the unit's own functions, types, and errors — both only as observable at the seam.
- **Debugging means a test gap** — if you're debugging, the tests weren't good enough. Before fixing, find the tree path that should have caught the bug (add it if it's missing), write the failing test, then fix the code.
- **Hexagonal** — domain pure; I/O in adapters; dependencies point inward; each driven port ships with an in-memory twin. Any mock or stub outside that twin must carry a visible marker naming the reason — silent mocking is never acceptable
- **No env-var behaviour switches** — do not use environment variables to vary behaviour between test and runtime
- **Functional first** — the outermost layer is real, max-validity functional testing at the highest tolerable realism: real driving and driven adapters, real infrastructure, real boundaries. The floor and the outside-in entry point is the **journey** — one expansive max-realism arc that spans multiple capabilities, establishes and works with the contexts they touch, passes through representative error paths (not every one — generic error handling is proven at lower layers), and eventually succeeds. The journey is **curated, never exhaustive**: keep it runnable in **under 5 minutes**, and when it runs longer, trim it — retain the highest-impact steps (most damaging if broken) and the most-recent steps (most likely to break); everything trimmed stays covered at lower layers. Re-evaluate and trim it whenever you work in it. **System** tests sit interior to the journey: the whole app wired with real driven adapters for a single capability. When breadth at max realism is unaffordable, lean on the journey and push combinatorial detail down to inner layers — never a broad in-memory-wired System suite. Inner layers exist only because a failing functional test demands them.
- **Outside-in** — start each capability from its outermost failing test at max realism — a **Journey** test for a new user-visible arc, otherwise a **System** test; it pulls the inner layers into being. Each discovered piece gets its own tree, TDD'd at its native layer with its own failing tests. The journey is curated, not auto-extended per capability. A green Journey or System test is not the goal — completeness at every layer is. Journey covers the user-visible arc across capabilities; System covers a single capability; inner trees own the combinatorial detail neither of them does.
- **Layer completeness** — every layer owns complete coverage of its own behaviour at its own seam. **Journey and functional coverage is never coverage of the layers beneath them.** A higher-layer test — green or red — never excuses a missing lower-layer test: implement only once a failing test exists at the behaviour's own ground layer, sitting *under* the journey/functional failure that motivated it. When a Journey or System test surfaces inner behaviour, that inner unit gets its own tree path and its own failing test before any code lands. Overlap across layers is intentional, not waste. "Already covered by X" is never a reason to skip Y, nor to implement off X's failure alone.
- **Descend to the lowest level, then fold back up** — run the failing higher-layer test, read its failure, and let it guide the next failing test one layer down: Journey → System → Component → Adapter → Use-case → Domain/Port. Keep descending to the lowest layer the behaviour reaches; never stop descending because the behaviour looks already covered above. Write the full ladder of tests down to the lowest level. Once the lowest-layer test passes, the layers fold back up — each higher-layer test passing in turn as the layers beneath it are satisfied, up to the Journey. A higher-layer test still failing means a layer beneath it lacks coverage: write another lower failing test before retrying upward.
- **Test layers** — Journey (curated user arc across capabilities and contexts, kept under 5 min, real everything, representative error paths, eventually succeeds), System (one capability wired whole-app against real infrastructure — the same surface Component covers, validated for real; selective), Component (one capability wired whole-app with real adapters, externals doubled at the edge — in-memory database, stubbed outbound HTTP, in-process; exhaustive), Adapter (driving mocks app, driven hits real infra), Use-case (in-memory adapters), Domain (pure). **Use-case is to Component as Journey is to System**: behaviour-oriented (Use-case, Journey) vs system-oriented (Component, System); the cheap tier (Use-case, Component) doubles what it can and is exhaustive, the real tier (System, Journey) integrates everything affordable and is selective
- **Shared port contract** — one `*.contract.ts` suite per port, imported by both in-memory-adapter and real-adapter test files
- **One tree, one test file** — each tree in `## Test Trees` reifies exactly one test file; the test file's describe/it hierarchy mirrors the tree verbatim (framework-agnostic contract)
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
