import assert from "node:assert/strict"
import { execFileSync, spawnSync } from "node:child_process"
import { chmodSync, copyFileSync, cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, it } from "node:test"

const releaseScripts = [
  fileURLToPath(new URL("../../scripts/publish-contree.sh", import.meta.url)),
  fileURLToPath(new URL("../../scripts/publish-trunk-sync.sh", import.meta.url)),
]

const sourceRoot = fileURLToPath(new URL("../..", import.meta.url))
const trunkSyncBuild = JSON.parse(readFileSync(join(sourceRoot, "trunk-sync/package.json"), "utf-8")).scripts.build

function git(cwd, ...args) {
  return execFileSync("git", ["-C", cwd, ...args], { encoding: "utf-8", stdio: ["ignore", "pipe", "pipe"] }).trim()
}

function setupTrunkSyncRelease({ rejectRef = null, unrelatedChanges = false } = {}) {
  const root = mkdtempSync(join(tmpdir(), "trunk-sync-release-"))
  const remote = mkdtempSync(join(tmpdir(), "trunk-sync-release-remote-"))
  for (const directory of [
    "scripts",
    "trunk-sync/scripts",
    "trunk-sync/.claude-plugin",
    "trunk-sync/.codex-plugin",
    "trunk-sync/dist/lib",
    "fake-bin",
  ]) mkdirSync(join(root, directory), { recursive: true })
  copyFileSync(releaseScripts[1], join(root, "scripts/publish-trunk-sync.sh"))
  copyFileSync(join(sourceRoot, "trunk-sync/scripts/bump-plugin-manifests.js"), join(root, "trunk-sync/scripts/bump-plugin-manifests.js"))
  copyFileSync(join(sourceRoot, "trunk-sync/package.json"), join(root, "trunk-sync/package.json"))
  copyFileSync(join(sourceRoot, "trunk-sync/tsconfig.json"), join(root, "trunk-sync/tsconfig.json"))
  copyFileSync(join(sourceRoot, "trunk-sync/.gitignore"), join(root, "trunk-sync/.gitignore"))
  cpSync(join(sourceRoot, "trunk-sync/src"), join(root, "trunk-sync/src"), { recursive: true })
  symlinkSync(join(sourceRoot, "trunk-sync/node_modules"), join(root, "trunk-sync/node_modules"), "dir")
  for (const host of [".claude-plugin", ".codex-plugin"]) {
    copyFileSync(join(sourceRoot, `trunk-sync/${host}/plugin.json`), join(root, `trunk-sync/${host}/plugin.json`))
  }
  const current = JSON.parse(readFileSync(join(root, "trunk-sync/.claude-plugin/plugin.json"), "utf-8")).version
  const [major, minor, patch] = current.split(".").map(BigInt)
  const nextVersion = `${major}.${minor}.${patch + 1n}`
  const notes = join(root, "notes.md")
  const ghCalled = join(root, "gh-called")
  const buildCalled = join(root, "build-called")
  writeFileSync(notes, "release notes\n")
  writeFileSync(join(root, "fake-bin/gh"), "#!/bin/sh\nprintf called > \"$GH_CALLED\"\n")
  writeFileSync(join(root, "fake-bin/pnpm"), "#!/bin/sh\n[ \"$1 $2\" = \"run build\" ] || exit 64\nprintf build > \"$BUILD_CALLED\"\nexec /bin/sh -c \"$BUILD_COMMAND\"\n")
  writeFileSync(join(root, "trunk-sync/dist/lib/stale.js"), "stale\n")
  chmodSync(join(root, "fake-bin/gh"), 0o755)
  chmodSync(join(root, "fake-bin/pnpm"), 0o755)

  execFileSync("git", ["init", "-b", "main", root], { stdio: "ignore" })
  git(root, "config", "user.email", "test@example.com")
  git(root, "config", "user.name", "Test")
  git(root, "add", ".")
  git(root, "commit", "-m", "seed")
  writeFileSync(join(root, "trunk-sync/dist/lib/untracked.js"), "untracked\n")
  execFileSync("git", ["init", "--bare", "-b", "main", remote], { stdio: "ignore" })
  git(root, "remote", "add", "origin", remote)
  git(root, "push", "origin", "main")
  const initialRemoteHead = execFileSync("git", ["--git-dir", remote, "rev-parse", "refs/heads/main"], { encoding: "utf-8" }).trim()

  if (unrelatedChanges) {
    writeFileSync(join(root, "unrelated-staged.txt"), "staged\n")
    git(root, "add", "unrelated-staged.txt")
    writeFileSync(join(root, "unrelated-worktree.txt"), "worktree\n")
  }

  if (rejectRef) {
    writeFileSync(join(remote, "hooks/update"), `#!/bin/sh\ncase "$1" in refs/${rejectRef}/*) exit 1;; esac\nexit 0\n`)
    chmodSync(join(remote, "hooks/update"), 0o755)
  }

  return {
    root,
    remote,
    notes,
    ghCalled,
    buildCalled,
    nextVersion,
    currentVersion: current,
    initialHead: initialRemoteHead,
    initialRemoteHead,
    cleanup() {
      rmSync(root, { recursive: true, force: true })
      rmSync(remote, { recursive: true, force: true })
    },
  }
}

function setupContreeRelease({ unwritableManifest = null, claudeUpdateFails = false, rejectRef = null, unrelatedChanges = false } = {}) {
  const root = mkdtempSync(join(tmpdir(), "contree-release-"))
  const remote = mkdtempSync(join(tmpdir(), "contree-release-remote-"))
  for (const directory of ["scripts", "contree/.claude-plugin", "contree/.codex-plugin", "fake-bin"]) {
    mkdirSync(join(root, directory), { recursive: true })
  }
  copyFileSync(releaseScripts[0], join(root, "scripts/publish-contree.sh"))
  copyFileSync(join(sourceRoot, "scripts/bump-plugin-version.js"), join(root, "scripts/bump-plugin-version.js"))
  for (const host of [".claude-plugin", ".codex-plugin"]) {
    copyFileSync(join(sourceRoot, `contree/${host}/plugin.json`), join(root, `contree/${host}/plugin.json`))
  }
  const current = JSON.parse(readFileSync(join(root, "contree/.claude-plugin/plugin.json"), "utf-8")).version
  const [major, minor, patch] = current.split("+")[0].split(".").map(BigInt)
  const nextVersion = `${major}.${minor}.${patch + 1n}`
  const notes = join(root, "notes.md")
  const ghCalled = join(root, "gh-called")
  const claudeCalled = join(root, "claude-called")
  const forbiddenBuildOrTest = join(root, "forbidden-build-or-test")
  const unwritableManifestPath = unwritableManifest ? join(root, "contree", unwritableManifest, "plugin.json") : ""
  writeFileSync(notes, "release notes\n")
  writeFileSync(join(root, "contree/source.txt"), "source\n")
  writeFileSync(join(root, "fake-bin/gh"), "#!/bin/sh\nprintf '%s\\n' \"$*\" > \"$GH_CALLED\"\n")
  writeFileSync(join(root, "fake-bin/claude"), "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$CLAUDE_CALLED\"\nif [ \"$1 $2\" = \"plugin update\" ] && [ \"$CLAUDE_UPDATE_FAILS\" = \"1\" ]; then exit 1; fi\n")
  writeFileSync(join(root, "fake-bin/node"), "#!/bin/sh\nif [ -n \"$UNWRITABLE_MANIFEST\" ]; then chmod 444 \"$UNWRITABLE_MANIFEST\"; fi\nexec \"$REAL_NODE\" \"$@\"\n")
  for (const command of ["npm", "pnpm"]) writeFileSync(join(root, `fake-bin/${command}`), "#!/bin/sh\nprintf called > \"$FORBIDDEN_BUILD_OR_TEST\"\nexit 64\n")
  chmodSync(join(root, "fake-bin/gh"), 0o755)
  chmodSync(join(root, "fake-bin/claude"), 0o755)
  chmodSync(join(root, "fake-bin/node"), 0o755)
  chmodSync(join(root, "fake-bin/npm"), 0o755)
  chmodSync(join(root, "fake-bin/pnpm"), 0o755)
  execFileSync("git", ["init", "-b", "main", root], { stdio: "ignore" })
  git(root, "config", "user.email", "test@example.com")
  git(root, "config", "user.name", "Test")
  git(root, "add", ".")
  git(root, "commit", "-m", "seed")
  execFileSync("git", ["init", "--bare", "-b", "main", remote], { stdio: "ignore" })
  git(root, "remote", "add", "origin", remote)
  git(root, "push", "origin", "main")
  const initialRemoteHead = execFileSync("git", ["--git-dir", remote, "rev-parse", "refs/heads/main"], { encoding: "utf-8" }).trim()
  if (unrelatedChanges) {
    writeFileSync(join(root, "unrelated-staged.txt"), "staged\n")
    git(root, "add", "unrelated-staged.txt")
    writeFileSync(join(root, "unrelated-worktree.txt"), "worktree\n")
  }
  if (rejectRef) {
    writeFileSync(join(remote, "hooks/update"), `#!/bin/sh\ncase "$1" in refs/${rejectRef}/*) exit 1;; esac\nexit 0\n`)
    chmodSync(join(remote, "hooks/update"), 0o755)
  }
  return {
    root,
    remote,
    notes,
    ghCalled,
    claudeCalled,
    forbiddenBuildOrTest,
    claudeUpdateFails,
    unwritableManifestPath,
    nextVersion,
    initialHead: git(root, "rev-parse", "HEAD"),
    initialRemoteHead,
    currentVersion: current,
    cleanup() {
      rmSync(root, { recursive: true, force: true })
      rmSync(remote, { recursive: true, force: true })
    },
  }
}

function releaseEnvironment(fixture) {
  return {
    ...process.env,
    PATH: `${join(fixture.root, "fake-bin")}:${join(sourceRoot, "trunk-sync/node_modules/.bin")}:${process.env.PATH}`,
    BUILD_CALLED: fixture.buildCalled,
    GH_CALLED: fixture.ghCalled,
    CLAUDE_CALLED: fixture.claudeCalled,
    CLAUDE_UPDATE_FAILS: fixture.claudeUpdateFails ? "1" : "0",
    UNWRITABLE_MANIFEST: fixture.unwritableManifestPath,
    REAL_NODE: process.execPath,
    BUILD_COMMAND: trunkSyncBuild,
    FORBIDDEN_BUILD_OR_TEST: fixture.forbiddenBuildOrTest,
  }
}

function pluginVersions(product) {
  return [".claude-plugin", ".codex-plugin"].map((host) => readFileSync(join(sourceRoot, product, host, "plugin.json"), "utf-8"))
}

function assertFileAbsent(path) {
  assert.throws(() => readFileSync(path, "utf-8"))
}

function canonicalBump(version, bump) {
  const [major, minor, patch] = version.split("+")[0].split(".").map(BigInt)
  if (bump === "major") return `${major + 1n}.0.0`
  if (bump === "minor") return `${major}.${minor + 1n}.0`
  return `${major}.${minor}.${patch + 1n}`
}

function assertUnrelatedChangesRemain(fixture) {
  assert.equal(git(fixture.root, "diff", "--cached", "--name-only"), "unrelated-staged.txt")
  const status = git(fixture.root, "status", "--porcelain")
  assert.match(status, /A  unrelated-staged\.txt/)
  assert.match(status, /\?\? unrelated-worktree\.txt/)
  assert.doesNotMatch(git(fixture.root, "show", "--format=", "--name-only", "HEAD"), /unrelated-/)
}

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

  describe("if either release command receives an unknown argument", () => {
    it("then it fails before release side effects and identifies the unknown argument", () => {
      for (const releaseScript of releaseScripts) {
        const result = spawnSync("bash", [releaseScript, "unexpected"], { encoding: "utf-8" })

        assert.equal(result.status, 1)
        assert.match(result.stderr, /unknown arg: unexpected/)
      }
    })
  })

  describe("when either release command is missing release notes", () => {
    it("then it fails before release side effects and provides the scoped history command for preparing them", () => {
      const versionsBefore = [pluginVersions("contree"), pluginVersions("trunk-sync")]
      const expectedScopes = [/-- contree\//, /-- trunk-sync\/ ':!trunk-sync\/dist\/'/]
      for (const [index, releaseScript] of releaseScripts.entries()) {
        const result = spawnSync("bash", [releaseScript, "patch"], { encoding: "utf-8" })

        assert.equal(result.status, 1)
        assert.match(result.stderr, /Release notes required/)
        assert.match(result.stderr, expectedScopes[index])
      }
      assert.deepEqual([pluginVersions("contree"), pluginVersions("trunk-sync")], versionsBefore)
    })
  })

  describe("if the supplied release-notes path does not exist", () => {
    it("then it fails before release side effects and identifies the missing path", () => {
      const missing = join(tmpdir(), "missing-plugin-release-notes.md")
      for (const releaseScript of releaseScripts) {
        const result = spawnSync("bash", [releaseScript, "patch", "--notes-file", missing], { encoding: "utf-8" })

        assert.equal(result.status, 1)
        assert.match(result.stderr, new RegExp(`Notes file not found: ${missing}`))
      }
    })
  })

  describe("if Trunk Sync source changes are uncommitted", () => {
    it("then publishing fails before building, bumping, or publishing and identifies the dirty source", () => {
      const fixture = setupTrunkSyncRelease()
      try {
        writeFileSync(join(fixture.root, "trunk-sync/src/lib/entry-input.ts"), "dirty source\n")
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-trunk-sync.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 1)
        assert.match(result.stderr, /Uncommitted source changes/)
        assert.match(result.stderr, /trunk-sync\/src\/lib\/entry-input\.ts/)
        assert.equal(git(fixture.root, "rev-parse", "HEAD"), fixture.initialRemoteHead)
        assertFileAbsent(fixture.buildCalled)
        assertFileAbsent(fixture.ghCalled)
      } finally {
        fixture.cleanup()
      }
    })
  })

  describe("if Trunk Sync has no checked-out branch", () => {
    it("then publishing fails before building, bumping, or publishing and requires a checked-out branch", () => {
      const fixture = setupTrunkSyncRelease()
      try {
        git(fixture.root, "checkout", "--detach")
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-trunk-sync.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 1)
        assert.match(result.stderr, /checked-out branch is required/)
        assert.equal(git(fixture.root, "rev-parse", "HEAD"), fixture.initialRemoteHead)
        assertFileAbsent(fixture.buildCalled)
        assertFileAbsent(fixture.ghCalled)
      } finally {
        fixture.cleanup()
      }
    })
  })

  describe("if Contree source changes are uncommitted", () => {
    it("then publishing fails before bumping or publishing and identifies the dirty source", () => {
      const fixture = setupContreeRelease()
      try {
        writeFileSync(join(fixture.root, "contree/source.txt"), "dirty source\n")
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-contree.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 1)
        assert.match(result.stderr, /Uncommitted changes/)
        assert.match(result.stderr, /contree\/source\.txt/)
        assert.equal(git(fixture.root, "rev-parse", "HEAD"), fixture.initialHead)
        assert.equal(JSON.parse(readFileSync(join(fixture.root, "contree/.claude-plugin/plugin.json"), "utf-8")).version, fixture.currentVersion)
        assertFileAbsent(fixture.ghCalled)
        assertFileAbsent(fixture.claudeCalled)
      } finally {
        fixture.cleanup()
      }
    })
  })

  describe("if Contree has no checked-out branch", () => {
    it("then publishing fails before bumping or publishing and requires a checked-out branch", () => {
      const fixture = setupContreeRelease()
      try {
        git(fixture.root, "checkout", "--detach")
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-contree.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 1)
        assert.match(result.stderr, /checked-out branch is required/)
        assert.equal(git(fixture.root, "rev-parse", "HEAD"), fixture.initialHead)
        assert.equal(execFileSync("git", ["--git-dir", fixture.remote, "rev-parse", "refs/heads/main"], { encoding: "utf-8" }).trim(), fixture.initialRemoteHead)
        assertFileAbsent(fixture.ghCalled)
        assertFileAbsent(fixture.claudeCalled)
      } finally {
        fixture.cleanup()
      }
    })
  })

  describe("if either Contree plugin manifest cannot be written", () => {
    it("then publishing fails and both manifests retain their original contents", () => {
      for (const unwritableManifest of [".claude-plugin", ".codex-plugin"]) {
        const fixture = setupContreeRelease({ unwritableManifest })
        try {
          const originals = [".claude-plugin", ".codex-plugin"].map((host) => readFileSync(join(fixture.root, "contree", host, "plugin.json"), "utf-8"))
          const result = spawnSync("bash", [join(fixture.root, "scripts/publish-contree.sh"), "patch", "--notes-file", fixture.notes], {
            cwd: fixture.root,
            encoding: "utf-8",
            env: releaseEnvironment(fixture),
          })

          assert.notEqual(result.status, 0, unwritableManifest)
          assert.deepEqual(
            [".claude-plugin", ".codex-plugin"].map((host) => readFileSync(join(fixture.root, "contree", host, "plugin.json"), "utf-8")),
            originals,
          )
          assert.equal(git(fixture.root, "rev-parse", "HEAD"), fixture.initialHead)
          assertFileAbsent(fixture.ghCalled)
          assertFileAbsent(fixture.claudeCalled)
        } finally {
          fixture.cleanup()
        }
      }
    })
  })

  describe("when the Trunk Sync release command publishes", () => {
    it("then it builds the marketplace runtime files without running tests", () => {
      const fixture = setupTrunkSyncRelease()
      try {
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-trunk-sync.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 0, result.stdout + result.stderr)
        assert.equal(readFileSync(fixture.buildCalled, "utf-8"), "build")
      } finally {
        fixture.cleanup()
      }
    })

    it("and stale or untracked runtime output is replaced by the generated bundle", () => {
      const fixture = setupTrunkSyncRelease()
      try {
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-trunk-sync.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 0, result.stdout + result.stderr)
        assert.throws(() => execFileSync("git", ["--git-dir", fixture.remote, "show", "refs/heads/main:trunk-sync/dist/lib/stale.js"], { stdio: "ignore" }))
        assert.throws(() => execFileSync("git", ["--git-dir", fixture.remote, "show", "refs/heads/main:trunk-sync/dist/lib/untracked.js"], { stdio: "ignore" }))
        assert.equal(
          execFileSync("git", ["--git-dir", fixture.remote, "show", "refs/heads/main:trunk-sync/dist/lib/entry-input.js"], { encoding: "utf-8" }),
          readFileSync(join(fixture.root, "trunk-sync/dist/lib/entry-input.js"), "utf-8"),
        )
      } finally {
        fixture.cleanup()
      }
    })

    it("and the release commit includes the generated marketplace runtime files", () => {
      const fixture = setupTrunkSyncRelease()
      try {
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-trunk-sync.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 0, result.stdout + result.stderr)
        assert.equal(
          execFileSync("git", ["--git-dir", fixture.remote, "show", "refs/heads/main:trunk-sync/dist/lib/entry-input.js"], { encoding: "utf-8" }),
          readFileSync(join(fixture.root, "trunk-sync/dist/lib/entry-input.js"), "utf-8"),
        )
      } finally {
        fixture.cleanup()
      }
    })

    it("and unrelated staged changes remain outside the release commit", () => {
      const fixture = setupTrunkSyncRelease({ unrelatedChanges: true })
      try {
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-trunk-sync.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 0, result.stdout + result.stderr)
        assertUnrelatedChangesRemain(fixture)
      } finally {
        fixture.cleanup()
      }
    })

    it("and it atomically pushes the release commit and annotated tag before creating the GitHub release", () => {
      const fixture = setupTrunkSyncRelease()
      try {
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-trunk-sync.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 0, result.stdout + result.stderr)
        const remoteVersion = execFileSync("git", ["--git-dir", fixture.remote, "show", "refs/heads/main:trunk-sync/.claude-plugin/plugin.json"], { encoding: "utf-8" })
        assert.equal(JSON.parse(remoteVersion).version, fixture.nextVersion)
        assert.equal(execFileSync("git", ["--git-dir", fixture.remote, "tag", "--list", `v${fixture.nextVersion}`], { encoding: "utf-8" }).trim(), `v${fixture.nextVersion}`)
        assert.equal(execFileSync("git", ["--git-dir", fixture.remote, "cat-file", "-t", `refs/tags/v${fixture.nextVersion}`], { encoding: "utf-8" }).trim(), "tag")
        assert.equal(readFileSync(fixture.ghCalled, "utf-8"), "called")
      } finally {
        fixture.cleanup()
      }
    })

    describe("if either ref is rejected by the remote", () => {
      it("then neither ref is published and no GitHub release is created", () => {
        for (const rejectRef of ["heads", "tags"]) {
          const fixture = setupTrunkSyncRelease({ rejectRef })
          try {
            const result = spawnSync("bash", [join(fixture.root, "scripts/publish-trunk-sync.sh"), "patch", "--notes-file", fixture.notes], {
              cwd: fixture.root,
              encoding: "utf-8",
              env: releaseEnvironment(fixture),
            })

            assert.notEqual(result.status, 0, rejectRef)
            assert.equal(execFileSync("git", ["--git-dir", fixture.remote, "rev-parse", "refs/heads/main"], { encoding: "utf-8" }).trim(), fixture.initialRemoteHead)
            assert.throws(() => execFileSync("git", ["--git-dir", fixture.remote, "show-ref", "--verify", `refs/tags/v${fixture.nextVersion}`], { stdio: "ignore" }))
            assert.throws(() => readFileSync(fixture.ghCalled, "utf-8"))
          } finally {
            fixture.cleanup()
          }
        }
      })

      it("and the generated local release commit and tag are removed so the same version bump can be retried", () => {
        const fixture = setupTrunkSyncRelease({ rejectRef: "tags", unrelatedChanges: true })
        try {
          const release = () => spawnSync("bash", [join(fixture.root, "scripts/publish-trunk-sync.sh"), "patch", "--notes-file", fixture.notes], {
            cwd: fixture.root,
            encoding: "utf-8",
            env: releaseEnvironment(fixture),
          })

          const rejected = release()

          assert.notEqual(rejected.status, 0)
          assert.equal(git(fixture.root, "rev-parse", "HEAD"), fixture.initialHead)
          assert.throws(() => git(fixture.root, "show-ref", "--verify", `refs/tags/v${fixture.nextVersion}`))
          for (const host of [".claude-plugin", ".codex-plugin"]) {
            assert.equal(JSON.parse(readFileSync(join(fixture.root, `trunk-sync/${host}/plugin.json`), "utf-8")).version, fixture.currentVersion)
          }
          assert.equal(readFileSync(join(fixture.root, "trunk-sync/dist/lib/stale.js"), "utf-8"), "stale\n")
          assert.equal(readFileSync(join(fixture.root, "trunk-sync/dist/lib/untracked.js"), "utf-8"), "untracked\n")
          assertFileAbsent(join(fixture.root, "trunk-sync/dist/lib/entry-input.js"))
          assertUnrelatedChangesRemain(fixture)

          rmSync(join(fixture.remote, "hooks/update"))
          const retried = release()

          assert.equal(retried.status, 0, retried.stdout + retried.stderr)
          assert.equal(JSON.parse(readFileSync(join(fixture.root, "trunk-sync/.claude-plugin/plugin.json"), "utf-8")).version, fixture.nextVersion)
          assert.equal(git(fixture.root, "cat-file", "-t", `refs/tags/v${fixture.nextVersion}`), "tag")
          assertUnrelatedChangesRemain(fixture)
        } finally {
          fixture.cleanup()
        }
      })
    })
  })

  describe("when the Contree release command has a semantic version change kind", () => {
    it("then it does not build or run tests", () => {
      const fixture = setupContreeRelease()
      try {
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-contree.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 0, result.stdout + result.stderr)
        assertFileAbsent(fixture.forbiddenBuildOrTest)
      } finally {
        fixture.cleanup()
      }
    })
  })

  describe("when the Contree release command publishes", () => {
    it("then it atomically pushes the release commit and annotated tag before creating the GitHub release", () => {
      const fixture = setupContreeRelease()
      try {
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-contree.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 0, result.stdout + result.stderr)
        const remoteVersion = execFileSync("git", ["--git-dir", fixture.remote, "show", "refs/heads/main:contree/.claude-plugin/plugin.json"], { encoding: "utf-8" })
        assert.equal(JSON.parse(remoteVersion).version, fixture.nextVersion)
        assert.equal(execFileSync("git", ["--git-dir", fixture.remote, "cat-file", "-t", `refs/tags/contree-v${fixture.nextVersion}`], { encoding: "utf-8" }).trim(), "tag")
        assert.match(readFileSync(fixture.ghCalled, "utf-8"), new RegExp(`release create contree-v${fixture.nextVersion}`))
      } finally {
        fixture.cleanup()
      }
    })

    it("and it refreshes the marketplace installation", () => {
      for (const claudeUpdateFails of [false, true]) {
        const fixture = setupContreeRelease({ claudeUpdateFails })
        try {
          const result = spawnSync("bash", [join(fixture.root, "scripts/publish-contree.sh"), "patch", "--notes-file", fixture.notes], {
            cwd: fixture.root,
            encoding: "utf-8",
            env: releaseEnvironment(fixture),
          })

          assert.equal(result.status, 0, result.stdout + result.stderr)
          assert.equal(git(fixture.root, "cat-file", "-t", `refs/tags/contree-v${fixture.nextVersion}`), "tag")
          assert.match(readFileSync(fixture.ghCalled, "utf-8"), new RegExp(`release create contree-v${fixture.nextVersion}`))
          const expectedRefresh = [
            "plugin marketplace update elimydlarz",
            "plugin update contree@elimydlarz --scope user",
          ]
          if (claudeUpdateFails) expectedRefresh.push("plugin install contree@elimydlarz --scope user")
          assert.deepEqual(readFileSync(fixture.claudeCalled, "utf-8").trim().split("\n"), expectedRefresh)
        } finally {
          fixture.cleanup()
        }
      }
    })

    it("and unrelated staged changes remain outside the release commit", () => {
      const fixture = setupContreeRelease({ unrelatedChanges: true })
      try {
        const result = spawnSync("bash", [join(fixture.root, "scripts/publish-contree.sh"), "patch", "--notes-file", fixture.notes], {
          cwd: fixture.root,
          encoding: "utf-8",
          env: releaseEnvironment(fixture),
        })

        assert.equal(result.status, 0, result.stdout + result.stderr)
        assertUnrelatedChangesRemain(fixture)
      } finally {
        fixture.cleanup()
      }
    })

    describe("if either ref is rejected by the remote", () => {
      it("then neither ref is published and no GitHub release is created", () => {
        for (const rejectRef of ["heads", "tags"]) {
          const fixture = setupContreeRelease({ rejectRef })
          try {
            const result = spawnSync("bash", [join(fixture.root, "scripts/publish-contree.sh"), "patch", "--notes-file", fixture.notes], {
              cwd: fixture.root,
              encoding: "utf-8",
              env: releaseEnvironment(fixture),
            })

            assert.notEqual(result.status, 0, rejectRef)
            assert.equal(execFileSync("git", ["--git-dir", fixture.remote, "rev-parse", "refs/heads/main"], { encoding: "utf-8" }).trim(), fixture.initialRemoteHead)
            assert.throws(() => execFileSync("git", ["--git-dir", fixture.remote, "show-ref", "--verify", `refs/tags/contree-v${fixture.nextVersion}`], { stdio: "ignore" }))
            assertFileAbsent(fixture.ghCalled)
            assertFileAbsent(fixture.claudeCalled)
          } finally {
            fixture.cleanup()
          }
        }
      })

      it("and the generated local release commit and tag are removed so the same version bump can be retried", () => {
        const fixture = setupContreeRelease({ rejectRef: "tags", unrelatedChanges: true })
        try {
          const release = () => spawnSync("bash", [join(fixture.root, "scripts/publish-contree.sh"), "patch", "--notes-file", fixture.notes], {
            cwd: fixture.root,
            encoding: "utf-8",
            env: releaseEnvironment(fixture),
          })

          const rejected = release()

          assert.notEqual(rejected.status, 0)
          assert.equal(git(fixture.root, "rev-parse", "HEAD"), fixture.initialHead)
          assert.throws(() => git(fixture.root, "show-ref", "--verify", `refs/tags/contree-v${fixture.nextVersion}`))
          for (const host of [".claude-plugin", ".codex-plugin"]) {
            assert.equal(JSON.parse(readFileSync(join(fixture.root, `contree/${host}/plugin.json`), "utf-8")).version, fixture.currentVersion)
          }
          assertUnrelatedChangesRemain(fixture)

          rmSync(join(fixture.remote, "hooks/update"))
          const retried = release()

          assert.equal(retried.status, 0, retried.stdout + retried.stderr)
          assert.equal(JSON.parse(readFileSync(join(fixture.root, "contree/.claude-plugin/plugin.json"), "utf-8")).version, fixture.nextVersion)
          assert.equal(git(fixture.root, "cat-file", "-t", `refs/tags/contree-v${fixture.nextVersion}`), "tag")
          assertUnrelatedChangesRemain(fixture)
        } finally {
          fixture.cleanup()
        }
      })
    })
  })

  describe("when the Contree release command publishes from a version with build metadata", () => {
    it("then the requested semantic component advances from the base version and the released version is canonical", () => {
      for (const bump of ["patch", "minor", "major"]) {
        const fixture = setupContreeRelease()
        try {
          assert.match(fixture.currentVersion, /^\d+\.\d+\.\d+\+codex\.\d+$/)
          const expected = canonicalBump(fixture.currentVersion, bump)
          const result = spawnSync("bash", [join(fixture.root, "scripts/publish-contree.sh"), bump, "--notes-file", fixture.notes], {
            cwd: fixture.root,
            encoding: "utf-8",
            env: releaseEnvironment(fixture),
          })

          assert.equal(result.status, 0, result.stdout + result.stderr)
          for (const host of [".claude-plugin", ".codex-plugin"]) {
            assert.equal(JSON.parse(readFileSync(join(fixture.root, `contree/${host}/plugin.json`), "utf-8")).version, expected)
          }
          assert.match(expected, /^\d+\.\d+\.\d+$/)
          assert.equal(git(fixture.root, "cat-file", "-t", `refs/tags/contree-v${expected}`), "tag")
        } finally {
          fixture.cleanup()
        }
      }
    })
  })

})
