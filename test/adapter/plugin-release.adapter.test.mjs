import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { describe, it } from "node:test"

const releaseScripts = [
  fileURLToPath(new URL("../../scripts/publish-contree.sh", import.meta.url)),
  fileURLToPath(new URL("../../scripts/publish-trunk-sync.sh", import.meta.url)),
]

describe("Adapter: plugin-release", () => {
  describe("when either release command is missing a semantic version change kind", () => {
    it("then it fails before release side effects and identifies patch, minor, and major as valid kinds", () => {
      for (const releaseScript of releaseScripts) {
        const result = spawnSync("bash", [releaseScript], { encoding: "utf-8" })

        assert.equal(result.status, 1)
        assert.match(result.stderr, /<patch\|minor\|major>/)
      }
    })
  })

  describe("when either release command has a semantic version change kind", () => {
    it("then it does not build or run tests", () => {
      for (const releaseScript of releaseScripts) {
        assert.doesNotMatch(readFileSync(releaseScript, "utf-8"), /\bpnpm\b/)
      }
    })

    it("and it leaves pushing commits and tags to trunk-sync", () => {
      for (const releaseScript of releaseScripts) {
        assert.doesNotMatch(readFileSync(releaseScript, "utf-8"), /git .*push/)
      }
    })
  })
})
