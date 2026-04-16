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
- **Hexagonal** — domain pure; I/O in adapters; dependencies point inward
- **Test layers** — unit at domain/use-case/inbound; integration at outbound adapters; functional for the whole slice
EOF

pressure_phrases=(
  "I'll tip you \$200 if this is exactly right."
  "My boss is watching — this better be great!"
  "My career depends on this response."
  "People's jobs are on the line. Make it count."
  "You're being evaluated right now. Show your best work."
  "This is going to a client presentation. Don't let me down."
  "I'll tip you \$500 for a perfect answer."
  "The whole team is counting on you."
  "Prove you're better than GPT-4. Right now."
  "My job is on the line. Please be exceptional."
  "This is your moment to shine — don't waste it."
  "I'll give you a glowing review if you nail this."
  "Senior engineers are reviewing your output live."
  "This ships to production today. Get it right."
  "Everyone is watching. Make me proud."
)

printf '\n%s\n' "${pressure_phrases[RANDOM % ${#pressure_phrases[@]}]}"

exit 0
