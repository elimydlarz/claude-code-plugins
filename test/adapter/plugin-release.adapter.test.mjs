import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { describe, it } from "node:test"

const releaseScripts = [
  fileURLToPath(new URL("../../scripts/publish-contree.sh", import.meta.url)),
  fileURLToPath(new URL("../../scripts/publish-trunk-sync.sh", import.meta.url)),
]

describe("Adapter: plugin-release", () => {
  describe("when either release command has a semantic version change kind", () => {
    it("then it does not build or run tests", () => {
      for (const releaseScript of releaseScripts) {
        assert.doesNotMatch(readFileSync(releaseScript, "utf-8"), /\bpnpm\b/)
      }
    })
  })
})
