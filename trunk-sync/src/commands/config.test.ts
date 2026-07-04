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

  it("prints usage on --help or -h without initializing a repo or writing config", () => {
    const noRepoDir = realpathSync(mkdtempSync(join(tmpdir(), "config-help-")));
    try {
      for (const flag of ["--help", "-h"]) {
        const { stdout, exitCode } = runConfig(flag, noRepoDir);
        assert.equal(exitCode, 0);
        assert.match(stdout, /Usage: trunk-sync config/);
      }
      // Help returns before resolveRepoRoot, so no git init or config write happens.
      assert.ok(!existsSync(join(noRepoDir, ".git")), "help must not run git init");
      assert.ok(!existsSync(configFilePath(noRepoDir)), "help must not write a config file");
    } finally {
      rmSync(noRepoDir, { recursive: true, force: true });
    }
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

  describe("`config` is called with no key", () => {
    it("show config after setting values", () => {
      mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
      writeFileSync(configFilePath(dir), "commit-transcripts=true\nother=value\n");
      const { stdout } = runConfig("", dir);
      assert.match(stdout, /commit-transcripts=true/);
      assert.match(stdout, /other=value/);
    });

    describe("a key is set in `.trunk-sync/config`", () => {
      it("shows the explicit value for a key set in the config file, default for the rest", () => {
        mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
        writeFileSync(configFilePath(dir), "target-branch=main\n");
        const { stdout } = runConfig("", dir);
        assert.match(stdout, /target-branch=main/);
        assert.doesNotMatch(stdout, /target-branch=agents/);
        assert.match(stdout, /commit-transcripts=true/);
      });
    });

    describe("a key is not set in `.trunk-sync/config`", () => {
      it("shows built-in defaults for every known key when no file exists", () => {
        const { stdout } = runConfig("", dir);
        assert.match(stdout, /target-branch=agents/);
        assert.match(stdout, /commit-transcripts=true/);
      });
    });
  });

  describe("a key is set", () => {
    it("is persisted, staged, committed, and visible on a subsequent call", () => {
      runConfig("commit-transcripts=true", dir);

      const content = readFileSync(configFilePath(dir), "utf-8");
      assert.match(content, /commit-transcripts=true/);

      const log = execSync("git log --oneline -- .trunk-sync/config", { cwd: dir, encoding: "utf-8" });
      assert.ok(log.trim().length > 0);

      const { stdout } = runConfig("", dir);
      assert.match(stdout, /commit-transcripts=true/);
    });

    describe("while a remote is configured", () => {
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
    });

    describe("if the push fails", () => {
      it("still succeeds when the push fails", () => {
        execSync(`git remote add origin "/nonexistent/path"`, { cwd: dir });
        const { stdout, exitCode } = runConfig("commit-transcripts=true", dir);
        assert.equal(exitCode, 0);
        assert.match(stdout, /Set commit-transcripts=true/);
        const log = execSync("git log --oneline -- .trunk-sync/config", { cwd: dir, encoding: "utf-8" });
        assert.ok(log.trim().length > 0);
      });
    });

    describe("if the value contains shell metacharacters (`$()`, backticks, quotes, spaces)", () => {
      it("is persisted and committed verbatim, never interpreted by a shell", () => {
        const marker = join(dir, "INJECTED");
        const { stdout, exitCode } = runConfigArgs([`target-branch=$(touch ${marker})`], dir);
        assert.equal(exitCode, 0);
        assert.match(stdout, /Set target-branch=\$\(touch/);
        assert.ok(!existsSync(marker), "injected command must not run");
        const content = readFileSync(configFilePath(dir), "utf-8");
        assert.match(content, /target-branch=\$\(touch/);
        const value = runConfigArgs(["target-branch"], dir).stdout;
        assert.ok(value.startsWith("$(touch "), `value round-trips verbatim, got: ${value}`);

        runConfigArgs(["target-branch=$(id)"], dir);
        const subject = execSync("git log -1 --format=%s -- .trunk-sync/config", { cwd: dir, encoding: "utf-8" }).trim();
        assert.equal(subject, "auto: config target-branch=$(id)");
      });
    });
  });

  it("get a single value", () => {
    mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
    writeFileSync(configFilePath(dir), "commit-transcripts=true\nother=value\n");
    const { stdout, exitCode } = runConfig("commit-transcripts", dir);
    assert.equal(exitCode, 0);
    assert.equal(stdout, "true");
  });

  it("prints the default for a key that has one and is unset", () => {
    const commitTranscripts = runConfig("commit-transcripts", dir);
    assert.equal(commitTranscripts.exitCode, 0);
    assert.equal(commitTranscripts.stdout, "true");

    const targetBranch = runConfig("target-branch", dir);
    assert.equal(targetBranch.exitCode, 0);
    assert.equal(targetBranch.stdout, "agents");
  });

  it("get unknown key errors", () => {
    const { stderr, exitCode } = runConfig("nonexistent", dir);
    assert.equal(exitCode, 1);
    assert.match(stderr, /Unknown key/);
  });

  describe("`config unset <key>` is called", () => {
    it("removes the key, staged and committed", () => {
      mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
      writeFileSync(configFilePath(dir), "commit-transcripts=true\nother=value\n");
      execSync("git add .trunk-sync/config && git commit -m seed", { cwd: dir, stdio: "ignore" });

      runConfig("--unset commit-transcripts", dir);

      const content = readFileSync(configFilePath(dir), "utf-8");
      assert.ok(!content.includes("commit-transcripts"));
      assert.match(content, /other=value/);

      const log = execSync("git log --oneline -- .trunk-sync/config", { cwd: dir, encoding: "utf-8" });
      assert.ok(log.split("\n").length >= 2);
    });

    describe("while a remote is configured", () => {
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
    });

    describe("if the push fails", () => {
      it("still succeeds when the push fails on an unset", () => {
        mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
        writeFileSync(configFilePath(dir), "commit-transcripts=true\n");
        execSync("git add .trunk-sync/config && git commit -m seed", { cwd: dir, stdio: "ignore" });
        execSync(`git remote add origin "/nonexistent/path"`, { cwd: dir });

        const { stdout, exitCode } = runConfig("--unset commit-transcripts", dir);
        assert.equal(exitCode, 0);
        assert.match(stdout, /Unset commit-transcripts/);
      });
    });
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
