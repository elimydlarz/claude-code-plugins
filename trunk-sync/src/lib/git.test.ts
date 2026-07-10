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

describe("getCommitSubject", () => {
  let dir: string;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "git-subject-test-"));
    execSync("git init", { cwd: dir });
    execSync('git config user.email "test@test.com"', { cwd: dir });
    execSync('git config user.name "Test"', { cwd: dir });
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("returns the commit's subject line", () => {
    const file = join(dir, "file.txt");
    writeFileSync(file, "hello\n");
    execSync("git add file.txt && git commit -m 'my subject line'", { cwd: dir });
    const sha = execSync("git rev-parse HEAD", { cwd: dir, encoding: "utf-8" }).trim();

    assert.equal(getCommitSubject(sha, dir), "my subject line");
  });
});

describe("getCommitDate", () => {
  let dir: string;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "git-date-test-"));
    execSync("git init", { cwd: dir });
    execSync('git config user.email "test@test.com"', { cwd: dir });
    execSync('git config user.name "Test"', { cwd: dir });
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("returns the commit's human-readable date", () => {
    const file = join(dir, "file.txt");
    writeFileSync(file, "hello\n");
    execSync("git add file.txt && git commit -m 'init'", { cwd: dir });
    const sha = execSync("git rev-parse HEAD", { cwd: dir, encoding: "utf-8" }).trim();

    const date = getCommitDate(sha, dir);
    assert.match(date, /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [+-]\d{4}$/);
  });
});

describe("getCommitTimestamp", () => {
  let dir: string;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "git-ts-test-"));
    execSync("git init", { cwd: dir });
    execSync('git config user.email "test@test.com"', { cwd: dir });
    execSync('git config user.name "Test"', { cwd: dir });
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("returns ISO timestamp for a commit", () => {
    const file = join(dir, "file.txt");
    writeFileSync(file, "hello\n");
    execSync("git add file.txt && git commit -m 'init'", { cwd: dir });
    const sha = execSync("git rev-parse HEAD", { cwd: dir, encoding: "utf-8" }).trim();

    const ts = getCommitTimestamp(sha, dir);
    // Should be a valid ISO date
    assert.ok(!isNaN(new Date(ts).getTime()), `Expected valid date, got: ${ts}`);
  });
});

describe("commandExists", () => {
  it("returns true for git", () => {
    assert.equal(commandExists("git"), true);
  });

  it("returns false for nonexistent command", () => {
    assert.equal(commandExists("nonexistent-xyz-command"), false);
  });
});

describe("shortSha", () => {
  it("returns first 8 chars", () => {
    assert.equal(shortSha("abcdef1234567890"), "abcdef12");
  });
});

describe("findSnapshotInCommit", () => {
  let dir: string;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "git-snapshot-test-"));
    execSync("git init", { cwd: dir });
    execSync('git config user.email "test@test.com"', { cwd: dir });
    execSync('git config user.name "Test"', { cwd: dir });
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("returns filename when .transcripts/ file in commit", () => {
    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    execSync("git add code.ts && git commit -m 'init'", { cwd: dir });

    const snapshotDir = join(dir, ".transcripts");
    mkdirSync(snapshotDir, { recursive: true });
    writeFileSync(join(snapshotDir, "abcd1234-1234567890.jsonl"), "data\n");
    execSync("git add .transcripts && git commit --amend --no-edit", { cwd: dir });

    const sha = execSync("git rev-parse HEAD", { cwd: dir, encoding: "utf-8" }).trim();
    const result = findSnapshotInCommit(sha, dir);
    assert.equal(result, ".transcripts/abcd1234-1234567890.jsonl");
  });

  it("returns null when no .transcripts/ file in commit", () => {
    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    execSync("git add code.ts && git commit -m 'init'", { cwd: dir });

    const sha = execSync("git rev-parse HEAD", { cwd: dir, encoding: "utf-8" }).trim();
    const result = findSnapshotInCommit(sha, dir);
    assert.equal(result, null);
  });
});
