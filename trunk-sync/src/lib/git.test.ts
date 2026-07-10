import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, realpathSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { execSync } from "node:child_process";
import { getGitRoot } from "./git.js";

describe("getGitRoot", () => {
  let dir: string;
  let originalCwd: string;

  beforeEach(() => {
    originalCwd = process.cwd();
    dir = mkdtempSync(join(tmpdir(), "git-root-test-"));
  });

  afterEach(() => {
    process.chdir(originalCwd);
    rmSync(dir, { recursive: true, force: true });
  });

  it("returns the repository root path when inside a git repository", () => {
    execSync("git init", { cwd: dir });
    process.chdir(dir);
    assert.equal(getGitRoot(), realpathSync(dir));
  });

  it("returns null when not inside a git repository", () => {
    process.chdir(dir);
    assert.equal(getGitRoot(), null);
  });
});
