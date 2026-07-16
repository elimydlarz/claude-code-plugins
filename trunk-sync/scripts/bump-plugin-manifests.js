#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs"

const [bump] = process.argv.slice(2)

if (!bump || !["patch", "minor", "major"].includes(bump)) {
  throw new Error("Usage: bump-plugin-manifests.js <patch|minor|major>")
}

const manifestPaths = [".claude-plugin/plugin.json", ".codex-plugin/plugin.json"]
const originals = manifestPaths.map((manifestPath) => readFileSync(manifestPath, "utf-8"))
const manifests = originals.map((content) => JSON.parse(content))
const currentVersion = manifests[0].version

if (!manifests.every((manifest) => manifest.version === currentVersion)) {
  throw new Error("Plugin manifest versions must match before bumping")
}
if (typeof currentVersion !== "string" || !/^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/.test(currentVersion)) {
  throw new Error("Plugin manifest version must contain exactly three numeric components")
}

const versions = manifests.map((manifest) => bumpVersion(manifest.version, bump))
const nextContents = manifests.map((manifest, index) => `${JSON.stringify({ ...manifest, version: versions[index] }, null, 2)}\n`)

let written = 0
try {
  for (const [index, manifestPath] of manifestPaths.entries()) {
    writeFileSync(manifestPath, nextContents[index])
    written += 1
  }
} catch (error) {
  for (let index = 0; index < written; index += 1) writeFileSync(manifestPaths[index], originals[index])
  throw error
}

process.stdout.write(`${versions[0]}\n`)

function bumpVersion(currentVersion, increment) {
  const [major, minor, patch] = currentVersion.split(".").map(BigInt)
  if (increment === "major") return `${major + 1n}.0.0`
  if (increment === "minor") return `${major}.${minor + 1n}.0`
  return `${major}.${minor}.${patch + 1n}`
}
