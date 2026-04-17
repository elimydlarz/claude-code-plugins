# CLAUDE.md

## Mental Model

A tiny bookmark API.

Two HTTP endpoints:

- `POST /bookmarks` with `{ url, title }` — validates the URL is well-formed, persists the bookmark, returns `{ id, url, title }`.
- `GET /bookmarks/:id` — retrieves a bookmark by id, returns `{ id, url, title }` or 404.

Persistence is via a `BookmarkRepository` port. The production adapter writes to a JSON file on disk. An in-memory adapter exists for fast tests.

Domain rule: URLs must start with `http://` or `https://` — reject with 400 otherwise.

## Repo Map

- `CLAUDE.md` — this file
- `package.json` — project manifest
