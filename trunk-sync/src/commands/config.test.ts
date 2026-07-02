import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, readFileSync, rmSync, existsSync, mkdirSync, realpathSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { execSync, execFileSync } from "node:child_process";

function initRepo(dir: string): void {
  execSync("git init", { cwd: dir, stdio: "ignore" });
  execSync('git config user.email "test@test.com"', { cwd: dir });
  execSync('git config user.name "Test"', { cwd: dir });
}

function runConfig(args: string, cwd: string): { stdout: string; stderr: string; exitCode: number } {
  const cliPath = join(process.cwd(), "dist", "cli.js");
  try {
    const stdout = execSync(`node "${cliPath}" config ${args}`, {
      encoding: "utf-8",
      cwd,
    }).trim();
    return { stdout, stderr: "", exitCode: 0 };
  } catch (e: unknown) {
    const err = e as { stderr?: string; stdout?: string; status?: number };
    return {
      stdout: (err.stdout || "").trim(),
      stderr: (err.stderr || "").trim(),
      exitCode: err.status ?? 1,
    };
  }
}

function runConfigArgs(args: string[], cwd: string): { stdout: string; stderr: string; exitCode: number } {
  const cliPath = join(process.cwd(), "dist", "cli.js");
  try {
    const stdout = execFileSync("node", [cliPath, "config", ...args], { encoding: "utf-8", cwd }).trim();
    return { stdout, stderr: "", exitCode: 0 };
  } catch (e: unknown) {
    const err = e as { stderr?: string; stdout?: string; status?: number };
    return {
      stdout: (err.stdout || "").trim(),
      stderr: (err.stderr || "").trim(),
      exitCode: err.status ?? 1,
    };
  }
}

function configFilePath(repoRoot: string): string {
  return join(repoRoot, ".trunk-sync", "config");
}

describe("config command", () => {
  let dir: string;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "config-test-")));
    initRepo(dir);
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("runs git init when run outside a git repo", () => {
    const noRepoDir = realpathSync(mkdtempSync(join(tmpdir(), "config-no-repo-")));
    try {
      const { stdout, exitCode } = runConfig("commit-transcripts", noRepoDir);
      assert.equal(exitCode, 0);
      assert.equal(stdout, "true");
      assert.ok(existsSync(join(noRepoDir, ".git")));
    } finally {
      rmSync(noRepoDir, { recursive: true, force: true });
    }
  });

  it("shows built-in defaults for every known key when no file exists", () => {
    const { stdout } = runConfig("", dir);
    assert.match(stdout, /target-branch=agents/);
    assert.match(stdout, /commit-transcripts=true/);
  });

  it("set a value", () => {
    runConfig("commit-transcripts=true", dir);
    const content = readFileSync(configFilePath(dir), "utf-8");
    assert.match(content, /commit-transcripts=true/);
  });

  it("a subsequent config call shows the value that was set", () => {
    runConfig("target-branch=main", dir);
    const { stdout } = runConfig("", dir);
    assert.match(stdout, /target-branch=main/);
  });

  it("commits the config change", () => {
    runConfig("commit-transcripts=true", dir);
    const log = execSync("git log --oneline -- .trunk-sync/config", { cwd: dir, encoding: "utf-8" });
    assert.ok(log.trim().length > 0);
  });

  it("pushes the commit when a remote is configured", () => {
    const remote = realpathSync(mkdtempSync(join(tmpdir(), "config-remote-")));
    execSync("git init --bare", { cwd: remote, stdio: "ignore" });
    execSync(`git remote add origin "${remote}"`, { cwd: dir });

    runConfig("commit-transcripts=false", dir);

    const check = realpathSync(mkdtempSync(join(tmpdir(), "config-check-")));
    execSync(`git clone "${remote}" .`, { cwd: check, stdio: "ignore" });
    const branches = execSync("git branch -r", { cwd: check, encoding: "utf-8" });
    assert.match(branches, /origin\/agents/); // pushed to the "agents" default target branch
    rmSync(remote, { recursive: true, force: true });
    rmSync(check, { recursive: true, force: true });
  });

  it("still succeeds when the push fails", () => {
    execSync(`git remote add origin "/nonexistent/path"`, { cwd: dir });
    const { stdout, exitCode } = runConfig("commit-transcripts=true", dir);
    assert.equal(exitCode, 0);
    assert.match(stdout, /Set commit-transcripts=true/);
    const log = execSync("git log --oneline -- .trunk-sync/config", { cwd: dir, encoding: "utf-8" });
    assert.ok(log.trim().length > 0);
  });

  it("show config after setting values", () => {
    mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
    writeFileSync(configFilePath(dir), "commit-transcripts=true\nother=value\n");
    const { stdout } = runConfig("", dir);
    assert.match(stdout, /commit-transcripts=true/);
    assert.match(stdout, /other=value/);
  });

  it("shows the explicit value for a key set in the config file, default for the rest", () => {
    mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
    writeFileSync(configFilePath(dir), "target-branch=main\n");
    const { stdout } = runConfig("", dir);
    assert.match(stdout, /target-branch=main/);
    assert.doesNotMatch(stdout, /target-branch=agents/);
    assert.match(stdout, /commit-transcripts=true/);
  });

  it("get a single value", () => {
    mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
    writeFileSync(configFilePath(dir), "commit-transcripts=true\nother=value\n");
    const { stdout, exitCode } = runConfig("commit-transcripts", dir);
    assert.equal(exitCode, 0);
    assert.equal(stdout, "true");
  });

  it("get key with default when not set", () => {
    const { stdout, exitCode } = runConfig("commit-transcripts", dir);
    assert.equal(exitCode, 0);
    assert.equal(stdout, "true");
  });

  it("target-branch defaults to agents when not set", () => {
    const { stdout, exitCode } = runConfig("target-branch", dir);
    assert.equal(exitCode, 0);
    assert.equal(stdout, "agents");
  });

  it("get unknown key errors", () => {
    const { stderr, exitCode } = runConfig("nonexistent", dir);
    assert.equal(exitCode, 1);
    assert.match(stderr, /Unknown key/);
  });

  it("unset a value", () => {
    mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
    writeFileSync(configFilePath(dir), "commit-transcripts=true\nother=value\n");
    execSync("git add .trunk-sync/config && git commit -m seed", { cwd: dir, stdio: "ignore" });
    runConfig("--unset commit-transcripts", dir);
    const content = readFileSync(configFilePath(dir), "utf-8");
    assert.ok(!content.includes("commit-transcripts"));
    assert.match(content, /other=value/);
  });

  it("commits an unset", () => {
    mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
    writeFileSync(configFilePath(dir), "commit-transcripts=true\n");
    execSync("git add .trunk-sync/config && git commit -m seed", { cwd: dir, stdio: "ignore" });
    runConfig("--unset commit-transcripts", dir);
    const log = execSync("git log --oneline -- .trunk-sync/config", { cwd: dir, encoding: "utf-8" });
    assert.ok(log.split("\n").length >= 2);
  });

  it("pushes an unset when a remote is configured", () => {
    mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
    writeFileSync(configFilePath(dir), "commit-transcripts=true\n");
    execSync("git add .trunk-sync/config && git commit -m seed", { cwd: dir, stdio: "ignore" });

    const remote = realpathSync(mkdtempSync(join(tmpdir(), "config-remote-")));
    execSync("git init --bare", { cwd: remote, stdio: "ignore" });
    execSync(`git remote add origin "${remote}"`, { cwd: dir });

    runConfig("--unset commit-transcripts", dir);

    const check = realpathSync(mkdtempSync(join(tmpdir(), "config-check-")));
    execSync(`git clone "${remote}" .`, { cwd: check, stdio: "ignore" });
    const log = execSync("git log --oneline origin/agents -- .trunk-sync/config", { cwd: check, encoding: "utf-8" });
    assert.match(log, /unset commit-transcripts/);
    rmSync(remote, { recursive: true, force: true });
    rmSync(check, { recursive: true, force: true });
  });

  it("still succeeds when the push fails on an unset", () => {
    mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
    writeFileSync(configFilePath(dir), "commit-transcripts=true\n");
    execSync("git add .trunk-sync/config && git commit -m seed", { cwd: dir, stdio: "ignore" });
    execSync(`git remote add origin "/nonexistent/path"`, { cwd: dir });

    const { stdout, exitCode } = runConfig("--unset commit-transcripts", dir);
    assert.equal(exitCode, 0);
    assert.match(stdout, /Unset commit-transcripts/);
  });

  it("unset nonexistent key errors", () => {
    const { stderr, exitCode } = runConfig("--unset nonexistent", dir);
    assert.equal(exitCode, 1);
    assert.match(stderr, /Key not found/);
  });

  it("handles comments and blank lines in config file", () => {
    mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
    writeFileSync(configFilePath(dir), "# comment\n\ncommit-transcripts=true\n");
    const { stdout } = runConfig("", dir);
    assert.match(stdout, /commit-transcripts=true/);
    assert.ok(!stdout.includes("#"));
  });
});
