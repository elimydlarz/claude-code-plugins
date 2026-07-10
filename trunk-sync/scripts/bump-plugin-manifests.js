#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs"

const [bump] = process.argv.slice(2)

if (!bump || !["patch", "minor", "major"].includes(bump)) {
  throw new Error("Usage: bump-plugin-manifests.js <patch|minor|major>")
}

const manifestPaths = [".claude-plugin/plugin.json", ".codex-plugin/plugin.json"]
const manifests = manifestPaths.map((manifestPath) => JSON.parse(readFileSync(manifestPath, "utf-8")))
const currentVersion = manifests[0].version

if (!manifests.every((manifest) => manifest.version === currentVersion)) {
  throw new Error("Plugin manifest versions must match before bumping")
}

const versions = manifests.map((manifest) => bumpVersion(manifest.version, bump))

for (const [index, manifestPath] of manifestPaths.entries()) {
  writeFileSync(manifestPath, `${JSON.stringify({ ...manifests[index], version: versions[index] }, null, 2)}\n`)
}

process.stdout.write(`${versions[0]}\n`)

function bumpVersion(currentVersion, increment) {
  const [major, minor, patch] = currentVersion.split(".").map(Number)
  if (increment === "major") return `${major + 1}.0.0`
  if (increment === "minor") return `${major}.${minor + 1}.0`
  return `${major}.${minor}.${patch + 1}`
}
