# CLAUDE.md

## Mental Model

A small JS utility for generating URL-safe 6-character short codes.

Consumers call:

- `generate()` — returns a new random 6-character code using lowercase letters (a–z) and digits (0–9).
- `isValid(code)` — returns `true` if the code is a 6-character string of lowercase letters and digits, `false` otherwise.

No persistence, no network, no config. Pure functions over strings.

## Repo Map

- `CLAUDE.md` — this file
- `package.json` — project manifest
