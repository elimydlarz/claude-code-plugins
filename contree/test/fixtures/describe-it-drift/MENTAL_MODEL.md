# Mental Model

## Core Domain Identity

A tiny Bookmark module canonicalises URL input and rejects non-URL input.

## World-to-Code Mapping

- `parseUrl(input)` maps a submitted URL string to JavaScript's canonical URL string.
- `InvalidUrl` is the domain error surfaced when input cannot be parsed as a URL.

## Ubiquitous Language

- Bookmark: the module boundary for URL parsing behaviour.
- Canonical form: the normalised string returned by `URL#toString()`.
- InvalidUrl: the error message used for non-URL strings.

## Bounded Contexts

Bookmark parsing is the only context in this fixture.

## Invariants

- Valid URL input returns a canonical URL string.
- Non-URL input throws `InvalidUrl`.
- Test file describe/it structure mirrors `TEST_TREES.md` when in sync.

## Decision Rationale

The fixture deliberately keeps code and tree behaviour aligned while leaving describe/it names drifted, so sync can isolate structural test drift.

## Temporal View

The current fixture state contains one intentional drift: `src/bookmark.domain.test.js` does not mirror the tree hierarchy.
