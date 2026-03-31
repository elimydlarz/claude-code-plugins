# CLAUDE.md

## Mental Model

A media player module. Loads and plays audio tracks. Has play/pause/stop controls. Tracks have a position that advances during playback. Pausing preserves position; stopping resets it. Only mp3 files are supported — other formats are rejected. Bluetooth audio output is available on devices that support it.

## Repo Map

- `player.js` — the player module
- `CLAUDE.md` — this file
