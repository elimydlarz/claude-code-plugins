import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { cpSync, mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { afterEach, describe, it } from "node:test"
import { fileURLToPath } from "node:url"

const source = fileURLToPath(new URL("../../scripts/sync-plugin-version.js", import.meta.url))
const directories = []

afterEach(() => {
  for (const directory of directories.splice(0)) rmSync(directory, { recursive: true, force: true })
})

describe("Adapter: plugin-version-sync", () => {
  describe("if either required plugin manifest is missing", () => {
    it("then synchronization fails", () => {
      const directory = mkdtempSync(join(tmpdir(), "trunk-sync-version-"))
      directories.push(directory)
      mkdirSync(join(directory, "scripts"))
      mkdirSync(join(directory, ".claude-plugin"))
      cpSync(source, join(directory, "scripts", "sync-plugin-version.js"))
      writeFileSync(join(directory, "package.json"), JSON.stringify({ type: "module", version: "9.8.7" }))
      writeFileSync(join(directory, ".claude-plugin", "plugin.json"), JSON.stringify({ version: "0.0.0" }))

      const result = spawnSync(process.execPath, ["scripts/sync-plugin-version.js"], { cwd: directory, encoding: "utf-8" })

      assert.notEqual(result.status, 0)
    })
  })
})
