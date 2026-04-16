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
