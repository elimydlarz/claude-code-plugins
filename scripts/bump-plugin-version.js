#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs"

const args = process.argv.slice(2)
const bump = args.at(-1)
const pluginPaths = args.slice(0, -1)

if (pluginPaths.length === 0 || !bump || !["patch", "minor", "major"].includes(bump)) {
  console.error("Usage: bump-plugin-version.js <plugin.json>... <patch|minor|major>")
  process.exit(1)
}

const originals = pluginPaths.map((pluginPath) => readFileSync(pluginPath, "utf8"))
const plugins = originals.map((original) => JSON.parse(original))
const versions = plugins.map(({ version }) => typeof version === "string"
  ? /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/.exec(version)
  : null)

if (versions.some((version) => version === null)) {
  console.error("Plugin version must be a canonical three-number semantic version with optional build metadata")
  process.exit(1)
}
if (!plugins.every(({ version }) => version === plugins[0].version)) {
  console.error("Plugin versions must match before bumping")
  process.exit(1)
}

const version = versions[0]
const major = BigInt(version[1])
const minor = BigInt(version[2])
const patch = BigInt(version[3])
const nextVersion = bump === "major"
  ? `${major + 1n}.0.0`
  : bump === "minor"
    ? `${major}.${minor + 1n}.0`
    : `${major}.${minor}.${patch + 1n}`
const nextContents = plugins.map((plugin) => `${JSON.stringify({ ...plugin, version: nextVersion }, null, 2)}\n`)

let written = 0
try {
  for (const [index, pluginPath] of pluginPaths.entries()) {
    writeFileSync(pluginPath, nextContents[index])
    written += 1
  }
} catch (error) {
  for (let index = 0; index < written; index += 1) writeFileSync(pluginPaths[index], originals[index])
  throw error
}

process.stdout.write(`${nextVersion}\n`)
