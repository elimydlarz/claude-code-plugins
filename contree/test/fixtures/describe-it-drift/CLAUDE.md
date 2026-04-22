# CLAUDE.md

## Mental Model

A tiny `Bookmark` module with one exported function, `parseUrl`. The
behaviour contract lives in [TEST_TREES.md](TEST_TREES.md). A test file
already exists — but its `describe`/`it` structure does NOT match the
tree.

## Repo Map

- `src/bookmark.js` — the module
- `src/bookmark.domain.test.js` — tests for the module (describe/it hierarchy drifts from the tree)
- `TEST_TREES.md` — behaviour contract
- `CLAUDE.md` — this file

## Test Trees

See [TEST_TREES.md](TEST_TREES.md).
