import assert from "node:assert/strict"
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { afterEach, describe, it } from "node:test"
import { spawnSync } from "node:child_process"

const source = fileURLToPath(new URL("../../scripts/bump-plugin-manifests.js", import.meta.url))
const directories = []

afterEach(() => {
  for (const directory of directories.splice(0)) rmSync(directory, { recursive: true, force: true })
})

describe("Adapter: plugin-version-bump", () => {
  describe("when a release bump runs", () => {
    it("then the Claude Code and Codex plugin manifests advance together from their shared version", () => {
      const directory = createPlugin("1.2.3", "1.2.3")

      const result = spawnSync(process.execPath, ["scripts/bump-plugin-manifests.js", "minor"], { cwd: directory, encoding: "utf-8" })

      assert.equal(result.status, 0, result.stderr)
      assert.equal(manifestVersion(directory, ".claude-plugin"), "1.3.0")
      assert.equal(manifestVersion(directory, ".codex-plugin"), "1.3.0")
      assert.equal(result.stdout.trim(), "1.3.0")
    })
  })

  describe("if either required plugin manifest is missing", () => {
    it("then the bump fails without modifying the existing manifest", () => {
      const directory = createPluginWithClaudeManifest("1.2.3")

      const result = spawnSync(process.execPath, ["scripts/bump-plugin-manifests.js", "patch"], { cwd: directory, encoding: "utf-8" })

      assert.notEqual(result.status, 0)
      assert.equal(manifestVersion(directory, ".claude-plugin"), "1.2.3")
    })
  })

  describe("if the plugin manifests have different versions", () => {
    it("then the bump fails without modifying either manifest", () => {
      const directory = createPlugin("1.2.3", "1.2.4")

      const result = spawnSync(process.execPath, ["scripts/bump-plugin-manifests.js", "patch"], { cwd: directory, encoding: "utf-8" })

      assert.notEqual(result.status, 0)
      assert.equal(manifestVersion(directory, ".claude-plugin"), "1.2.3")
      assert.equal(manifestVersion(directory, ".codex-plugin"), "1.2.4")
    })
  })
})

function createPlugin(claudeVersion, codexVersion) {
  const directory = mkdtempSync(join(tmpdir(), "trunk-sync-version-"))
  directories.push(directory)
  mkdirSync(join(directory, "scripts"), { recursive: true })
  cpSync(source, join(directory, "scripts", "bump-plugin-manifests.js"))
  writeManifest(directory, ".claude-plugin", claudeVersion)
  writeManifest(directory, ".codex-plugin", codexVersion)
  return directory
}

function createPluginWithClaudeManifest(version) {
  const directory = mkdtempSync(join(tmpdir(), "trunk-sync-version-"))
  directories.push(directory)
  mkdirSync(join(directory, "scripts"), { recursive: true })
  cpSync(source, join(directory, "scripts", "bump-plugin-manifests.js"))
  writeManifest(directory, ".claude-plugin", version)
  return directory
}

function writeManifest(directory, manifestDirectory, version) {
  const path = join(directory, manifestDirectory, "plugin.json")
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, `${JSON.stringify({ name: "trunk-sync", version }, null, 2)}\n`)
}

function manifestVersion(directory, manifestDirectory) {
  return JSON.parse(readFileSync(join(directory, manifestDirectory, "plugin.json"), "utf-8")).version
}
