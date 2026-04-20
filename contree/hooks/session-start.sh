#!/usr/bin/env bash
# SessionStart hook: print rules plus one random pressure phrase to stdout.
# Claude Code injects SessionStart stdout (exit 0) into the model's context.

cat <<'EOF'
# Rules

- **KISS** — complexity is bad; simplicity above almost all else
- **YAGNI** — don't future-proof; implement only what you need now
- **Subtract, don't add** — can this be achieved by simplification instead?
- **No fake code** — no skeletons, placeholders, or temporary implementations
- **Avoid indirection** — direct is better than conforming to arbitrary patterns
- **Fail fast** — don't swallow errors; let the system fail when unexpected things happen
- **Avoid nullability** — make things required; don't program defensively
- **Explicit and expressive** — name for what things do, not how they're implemented
- **Self-documenting** — no comments; use clear naming and structure
- **Composition over inheritance** — no `extends`; use hooks, functional utilities, component composition
- **Typing** — type everything; no `any`
- **Z-index** — avoid z-index; good layout doesn't rely on it
- **Read docs** — use Context7 before using any library; don't guess API usage
- **Consumer-driven** — implement only what a consumer already needs
- **Resolve uncertainty** — look directly and remove optionality; don't hedge with fallbacks
- **pnpm** — use pnpm, not npm, for JS/TS
- **Trees are the contract** — every expected behaviour and side effect goes in `## Test Trees`; every tree is verified by a test; every test drives the real implementation. File writes, external calls, state mutations, and cleanup all count as behaviour — if it's observable anywhere (filesystem, network, logs, next invocation), it belongs in the tree. If you're wondering whether an expectation belongs in the trees, the answer is yes.
- **Debugging means a test gap** — if you're debugging, the tests weren't good enough. Before fixing, find the tree path that should have caught the bug (add it if it's missing), write the failing test, then fix the code.
- **Hexagonal** — domain pure; I/O in adapters; dependencies point inward; each driven port ships with an in-memory twin
- **Test layers** — Domain (pure), Use-case (in-memory adapters), Adapter (driving mocks app, driven hits real infra), System (whole app, in-memory by default)
- **Shared port contract** — one `*.contract.ts` suite per port, imported by both in-memory-adapter and real-adapter test files
- **One tree, one test file** — each tree in `## Test Trees` reifies exactly one test file; describe/it hierarchy mirrors the tree
EOF

printf '\n'
bash "$(dirname "${BASH_SOURCE[0]}")/pressure-phrases.sh"

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
