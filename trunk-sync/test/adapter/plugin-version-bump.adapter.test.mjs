import assert from "node:assert/strict"
import { chmodSync, cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
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
    describe("when the bump is patch, minor, or major", () => {
      it("then the Claude Code and Codex plugin manifests advance together from their shared version", () => {
        for (const [bump, expected] of [["patch", "1.2.4"], ["minor", "1.3.0"], ["major", "2.0.0"]]) {
          const directory = createPlugin("1.2.3", "1.2.3")

          const result = spawnSync(process.execPath, ["scripts/bump-plugin-manifests.js", bump], { cwd: directory, encoding: "utf-8" })

          assert.equal(result.status, 0, `${bump}: ${result.stderr}`)
          assert.equal(manifestVersion(directory, ".claude-plugin"), expected)
          assert.equal(manifestVersion(directory, ".codex-plugin"), expected)
          assert.equal(result.stdout.trim(), expected)
        }
      })

      it("and numeric components advance without precision loss", () => {
        const directory = createPlugin("9007199254740993.2.3", "9007199254740993.2.3")

        const result = spawnSync(process.execPath, ["scripts/bump-plugin-manifests.js", "major"], { cwd: directory, encoding: "utf-8" })

        assert.equal(result.status, 0, result.stderr)
        assert.equal(manifestVersion(directory, ".claude-plugin"), "9007199254740994.0.0")
        assert.equal(manifestVersion(directory, ".codex-plugin"), "9007199254740994.0.0")
      })
    })
  })

  describe("if the Claude Code or Codex plugin manifest is missing", () => {
    it("then the bump fails without modifying the existing manifest", () => {
      for (const existingManifest of [".claude-plugin", ".codex-plugin"]) {
        const directory = createPluginWithOneManifest(existingManifest, "1.2.3")

        const result = spawnSync(process.execPath, ["scripts/bump-plugin-manifests.js", "patch"], { cwd: directory, encoding: "utf-8" })

        assert.notEqual(result.status, 0)
        assert.equal(manifestVersion(directory, existingManifest), "1.2.3")
      }
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

  describe("if the shared version is not a canonical three-number semantic version", () => {
    it("then the bump fails without modifying either manifest", () => {
      for (const version of ["1.2", "01.2.3", "1.02.3", "1.2.03"]) {
        const directory = createPlugin(version, version)

        const result = spawnSync(process.execPath, ["scripts/bump-plugin-manifests.js", "patch"], { cwd: directory, encoding: "utf-8" })

        assert.notEqual(result.status, 0, version)
        assert.equal(manifestVersion(directory, ".claude-plugin"), version)
        assert.equal(manifestVersion(directory, ".codex-plugin"), version)
      }
    })
  })

  describe("if either bumped manifest cannot be written", () => {
    it("then the bump fails and both manifests retain their original contents", () => {
      for (const readOnlyManifest of [".claude-plugin", ".codex-plugin"]) {
        const directory = createPlugin("1.2.3", "1.2.3")
        const readOnlyPath = join(directory, readOnlyManifest, "plugin.json")
        chmodSync(readOnlyPath, 0o444)

        const result = spawnSync(process.execPath, ["scripts/bump-plugin-manifests.js", "patch"], { cwd: directory, encoding: "utf-8" })

        chmodSync(readOnlyPath, 0o644)
        assert.notEqual(result.status, 0, readOnlyManifest)
        assert.equal(manifestVersion(directory, ".claude-plugin"), "1.2.3")
        assert.equal(manifestVersion(directory, ".codex-plugin"), "1.2.3")
      }
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

function createPluginWithOneManifest(manifestDirectory, version) {
  const directory = mkdtempSync(join(tmpdir(), "trunk-sync-version-"))
  directories.push(directory)
  mkdirSync(join(directory, "scripts"), { recursive: true })
  cpSync(source, join(directory, "scripts", "bump-plugin-manifests.js"))
  writeManifest(directory, manifestDirectory, version)
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
