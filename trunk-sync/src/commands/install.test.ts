import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, readFileSync, rmSync, chmodSync, realpathSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { execSync, spawnSync } from "node:child_process";

const nodeBin = execSync("which node", { encoding: "utf-8" }).trim();
const nodeDir = join(nodeBin, "..");

function runInstall(
  args: string,
  env?: Record<string, string>,
  cwd?: string,
): { stdout: string; stderr: string; exitCode: number } {
  const cliPath = join(process.cwd(), "dist", "cli.js");
  // spawnSync captures stdout AND stderr on every exit code (success included),
  // so warnings emitted via console.warn on a clean exit are observable.
  const result = spawnSync(
    process.execPath,
    [cliPath, "install", ...args.split(/\s+/).filter(Boolean)],
    {
      cwd,
      encoding: "utf-8",
      env: { ...process.env, ...env, PATH: env?.PATH ? `${env.PATH}:${nodeDir}` : process.env.PATH },
    },
  );
  return {
    stdout: (result.stdout || "").trim(),
    stderr: (result.stderr || "").trim(),
    exitCode: result.status ?? 1,
  };
}

function makeFakeBin(dir: string, name: string, script = "#!/bin/sh\nexit 0"): void {
  const binPath = join(dir, name);
  writeFileSync(binPath, script);
  chmodSync(binPath, 0o755);
}

describe("install command", () => {
  let fakeBinDir: string;
  let gitDir: string;
  let cleanupDirs: string[];

  beforeEach(() => {
    fakeBinDir = realpathSync(mkdtempSync(join(tmpdir(), "install-bins-")));
    gitDir = realpathSync(mkdtempSync(join(tmpdir(), "install-git-")));
    execSync("git init", { cwd: gitDir, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: gitDir });
    execSync('git config user.name "Test"', { cwd: gitDir });
    writeFileSync(join(gitDir, "seed.txt"), "seed\n");
    execSync("git add seed.txt && git commit -m seed", { cwd: gitDir, stdio: "ignore" });
    cleanupDirs = [fakeBinDir, gitDir];
  });

  afterEach(() => {
    for (const d of cleanupDirs) {
      rmSync(d, { recursive: true, force: true });
    }
  });

  it("--help prints usage", () => {
    const { stdout, exitCode } = runInstall("--help");
    assert.equal(exitCode, 0);
    assert.match(stdout, /Usage/);
  });

  it("fails when jq is missing", () => {
    makeFakeBin(fakeBinDir, "claude");
    // Only our fake bin dir + node dir in PATH — no system jq
    const { stderr, exitCode } = runInstall("", { PATH: fakeBinDir }, gitDir);
    assert.equal(exitCode, 1);
    assert.match(stderr, /jq/);
  });

  it("fails when claude is missing", () => {
    makeFakeBin(fakeBinDir, "jq");
    const { exitCode, stderr } = runInstall("", { PATH: fakeBinDir }, gitDir);
    assert.equal(exitCode, 1);
    assert.match(stderr, /[Cc]laude/);
  });

  it("warns when not in git repo (project scope)", () => {
    const noGitDir = realpathSync(mkdtempSync(join(tmpdir(), "no-git-install-")));
    cleanupDirs.push(noGitDir);
    makeFakeBin(fakeBinDir, "jq");
    makeFakeBin(fakeBinDir, "claude");

    const { stdout, stderr } = runInstall("", { PATH: fakeBinDir }, noGitDir);
    // Warning goes to stderr via console.warn; install still succeeds.
    assert.match(stdout, /installed successfully/);
    assert.match(stderr, /not inside a git repository/);
  });

  it("suppresses git warning for user scope", () => {
    const noGitDir = realpathSync(mkdtempSync(join(tmpdir(), "no-git-install-")));
    cleanupDirs.push(noGitDir);
    makeFakeBin(fakeBinDir, "jq");
    makeFakeBin(fakeBinDir, "claude");

    const { stdout, stderr } = runInstall("--scope user", { PATH: fakeBinDir }, noGitDir);
    assert.doesNotMatch(stdout + stderr, /not inside a git repository/);
    assert.match(stdout, /installed successfully/);
  });

  it("rejects invalid scope", () => {
    const { stderr, exitCode } = runInstall("--scope invalid");
    assert.equal(exitCode, 1);
    assert.match(stderr, /scope/i);
  });

  it("passes scope to claude commands", () => {
    makeFakeBin(fakeBinDir, "jq");

    const logFile = join(fakeBinDir, "claude.log");
    makeFakeBin(
      fakeBinDir,
      "claude",
      `#!/bin/sh\necho "$@" >> "${logFile}"\nexit 0`,
    );

    runInstall("--scope user", { PATH: fakeBinDir }, gitDir);

    // One line per fake-claude invocation. Assert the scope reached BOTH the
    // marketplace-add and the plugin-install commands — not just one of them.
    const lines = readFileSync(logFile, "utf-8").split("\n").filter(Boolean);
    const addLine = lines.find((l) => /marketplace add/.test(l));
    const installLine = lines.find((l) => /plugin install/.test(l));
    assert.ok(addLine, "claude plugin marketplace add was invoked");
    assert.match(addLine, /--scope user/);
    assert.ok(installLine, "claude plugin install was invoked");
    assert.match(installLine, /--scope user/);
  });

  it("--client codex writes a marketplace entry into HOME/.agents/plugins/marketplace.json", () => {
    const fakeHome = realpathSync(mkdtempSync(join(tmpdir(), "codex-home-")));
    cleanupDirs.push(fakeHome);
    makeFakeBin(fakeBinDir, "jq");

    const { stdout, exitCode } = runInstall(
      "--client codex",
      { PATH: fakeBinDir, HOME: fakeHome },
      gitDir,
    );

    assert.equal(exitCode, 0);
    assert.match(stdout, /\/plugins install trunk-sync/);

    const marketplacePath = join(fakeHome, ".agents", "plugins", "marketplace.json");
    const marketplace = JSON.parse(readFileSync(marketplacePath, "utf-8"));
    assert.equal(marketplace.name, "elimydlarz");
    const entry = marketplace.plugins.find((p: { name: string }) => p.name === "trunk-sync");
    assert.ok(entry, "trunk-sync entry present");
    assert.equal(entry.source.source, "git-subdir");
    assert.equal(entry.source.url, "https://github.com/elimydlarz/claude-code-plugins.git");
    assert.equal(entry.source.path, "./trunk-sync");
    assert.equal(entry.policy.installation, "AVAILABLE");
    assert.equal(entry.policy.authentication, "ON_INSTALL");
  });

  it("--client codex is idempotent and does not duplicate the entry", () => {
    const fakeHome = realpathSync(mkdtempSync(join(tmpdir(), "codex-home-")));
    cleanupDirs.push(fakeHome);
    makeFakeBin(fakeBinDir, "jq");

    runInstall("--client codex", { PATH: fakeBinDir, HOME: fakeHome }, gitDir);
    runInstall("--client codex", { PATH: fakeBinDir, HOME: fakeHome }, gitDir);

    const marketplacePath = join(fakeHome, ".agents", "plugins", "marketplace.json");
    const marketplace = JSON.parse(readFileSync(marketplacePath, "utf-8"));
    const entries = marketplace.plugins.filter((p: { name: string }) => p.name === "trunk-sync");
    assert.equal(entries.length, 1);
  });

  it("--client codex preserves unrelated existing plugins in marketplace.json", () => {
    const fakeHome = realpathSync(mkdtempSync(join(tmpdir(), "codex-home-")));
    cleanupDirs.push(fakeHome);
    makeFakeBin(fakeBinDir, "jq");

    const marketplacePath = join(fakeHome, ".agents", "plugins", "marketplace.json");
    const dir = join(fakeHome, ".agents", "plugins");
    execSync(`mkdir -p "${dir}"`);
    writeFileSync(
      marketplacePath,
      JSON.stringify({
        name: "elimydlarz",
        plugins: [
          {
            name: "other-plugin",
            source: { source: "local", path: "./other" },
            policy: { installation: "AVAILABLE", authentication: "ON_INSTALL" },
            category: "Productivity",
          },
        ],
      }) + "\n",
    );

    runInstall("--client codex", { PATH: fakeBinDir, HOME: fakeHome }, gitDir);

    const marketplace = JSON.parse(readFileSync(marketplacePath, "utf-8"));
    assert.equal(marketplace.plugins.length, 2);
    assert.ok(marketplace.plugins.find((p: { name: string }) => p.name === "other-plugin"));
    assert.ok(marketplace.plugins.find((p: { name: string }) => p.name === "trunk-sync"));
  });

  it("rejects invalid --client value", () => {
    const { stderr, exitCode } = runInstall("--client gemini");
    assert.equal(exitCode, 1);
    assert.match(stderr, /[Cc]lient/);
  });
});
