# Mental Model

This repository is the **elimydlarz monorepo** — several independent products that happen to share a marketplace, a publish pipeline, and one git history. It has **no single mental model, by design.**

Each product owns its mental model in its own `MENTAL_MODEL.md`:

- [trunk-sync](trunk-sync/MENTAL_MODEL.md) — branch-scoped multi-agent continuous integration and presence via Claude Code and Codex hooks.
- [contree](contree/MENTAL_MODEL.md) — test trees as living requirements; outside-in TDD across its operator-facing layers and native hexagonal seams.

## Why this file only references — and must stay that way

- **The products have disjoint domains, vocabularies, and invariants.** A continuous-integration git hook and a test-tree methodology share almost no concepts. A single combined mental model would force false unification and bury each product's real invariants.
- **The monorepo-level "theory" is operational, not domain** — what lives here, how it's published, how the marketplace works. That belongs in [CLAUDE.md](CLAUDE.md), not here.
- **So this is an index, not a seven-section mental model.** Do not convert it into one, and do not fold the per-product models into it. If you find yourself wanting a "shared" section, that concept belongs to a specific product — put it there.
- **The mental-model validator will flag this file** as missing the seven named sections and carrying a rogue heading. That warning is **expected and intentional** here: this is the monorepo index, not a product mental model. Do not "fix" it by adding the seven sections.
- **Adding a product?** Give it its own `MENTAL_MODEL.md` and add one link above. Nothing else here changes.
