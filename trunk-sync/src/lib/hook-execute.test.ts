import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync,
  writeFileSync,
  readFileSync,
  rmSync,
  unlinkSync,
  mkdirSync,
  realpathSync,
  existsSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir, hostname } from "node:os";
import { execSync } from "node:child_process";
import type { HookInput, RepoState, HookPlan, SyncPlan, ClockInPlan, Timecard } from "./hook-types.js";
import { gatherRepoState, findWorktreeForBranch, executePlan, executeSync, clockIn, readTimecards, isProcessAlive, clockOutStale } from "./hook-execute.js";

// ── Helpers ──────────────────────────────────────────────────────────

function initRepo(dir: string): void {
  execSync("git init", { cwd: dir, stdio: "ignore" });
  execSync('git config user.email "test@test.com"', { cwd: dir });
  execSync('git config user.name "Test"', { cwd: dir });
}

function makeInput(overrides: Partial<HookInput> = {}): HookInput {
  return {
    tool_name: "Write",
    tool_input: {},
    session_id: null,
    transcript_path: null,
    ...overrides,
  };
}

function makeState(dir: string, overrides: Partial<RepoState> = {}): RepoState {
  const gitDir = join(dir, ".git");
  return {
    repoRoot: dir,
    gitDir,
    relPath: null,
    insideRepo: true,
    gitignored: false,
    hasRemote: false,
    targetBranch: "main",
    currentBranch: "main",
    inMerge: false,
    hasStagedChanges: false,
    deletedFiles: [],
    modifiedFiles: [],
    ...overrides,
  };
}

function setupRepoWithRemote(prefix: string): {
  remote: string;
  clone: string;
  targetBranch: string;
} {
  const remote = realpathSync(mkdtempSync(join(tmpdir(), `${prefix}-remote-`)));
  execSync("git init --bare", { cwd: remote, stdio: "ignore" });

  const clone = realpathSync(mkdtempSync(join(tmpdir(), `${prefix}-clone-`)));
  execSync(`git clone "${remote}" .`, { cwd: clone, stdio: "ignore" });
  execSync('git config user.email "test@test.com"', { cwd: clone });
  execSync('git config user.name "Test"', { cwd: clone });

  // Initial commit
  writeFileSync(join(clone, "init.txt"), "init\n");
  execSync("git add init.txt && git commit -m init", { cwd: clone, stdio: "ignore" });
  execSync("git push origin main", { cwd: clone, stdio: "ignore" });

  return { remote, clone, targetBranch: "main" };
}

function jsonl(...objects: unknown[]): string {
  return objects.map((o) => JSON.stringify(o)).join("\n");
}

// ── gatherRepoState ──────────────────────────────────────────────────

describe("gatherRepoState", () => {
  let dir: string;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "hook-exec-test-")));
    initRepo(dir);
    writeFileSync(join(dir, "file.txt"), "hello\n");
    execSync("git add file.txt && git commit -m init", { cwd: dir });
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("returns null outside a git repo", () => {
    const tmpDir = mkdtempSync(join(tmpdir(), "no-git-"));
    try {
      const origDir = process.cwd();
      process.chdir(tmpDir);
      const state = gatherRepoState(makeInput());
      process.chdir(origDir);
      assert.equal(state, null);
    } finally {
      rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  it("detects repo root and git dir", () => {
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(
      makeInput({ tool_input: { file_path: join(dir, "file.txt") } }),
    );
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.repoRoot, dir);
    assert.equal(state.insideRepo, true);
    assert.equal(state.relPath, "file.txt");
  });

  it("detects file outside repo", () => {
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(
      makeInput({ tool_input: { file_path: "/tmp/outside.txt" } }),
    );
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.insideRepo, false);
  });

  it("detects gitignored files", () => {
    writeFileSync(join(dir, ".gitignore"), "ignored.txt\n");
    execSync("git add .gitignore && git commit -m 'add gitignore'", { cwd: dir });
    writeFileSync(join(dir, "ignored.txt"), "secret\n");
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(
      makeInput({ tool_input: { file_path: join(dir, "ignored.txt") } }),
    );
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.gitignored, true);
  });

  it("detects no remote", () => {
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.hasRemote, false);
  });

  it("detects deleted files", () => {
    rmSync(join(dir, "file.txt"));
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.deepEqual(state.deletedFiles, ["file.txt"]);
  });

  it("detects modified files when no file_path", () => {
    // Change content of tracked file
    writeFileSync(join(dir, "file.txt"), "modified\n");
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.deepEqual(state.modifiedFiles, ["file.txt"]);
  });

  it("detects permission changes when no file_path", () => {
    execSync(`chmod +x "${join(dir, "file.txt")}"`);
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.deepEqual(state.modifiedFiles, ["file.txt"]);
  });

  it("does not detect modified files when file_path is provided", () => {
    writeFileSync(join(dir, "file.txt"), "modified\n");
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(
      makeInput({ tool_input: { file_path: join(dir, "file.txt") } }),
    );
    process.chdir(origDir);
    assert.ok(state);
    assert.deepEqual(state.modifiedFiles, []);
  });
});

// ── findWorktreeForBranch ────────────────────────────────────────────

describe("findWorktreeForBranch", () => {
  it("finds worktree for a branch", () => {
    const porcelain = [
      "worktree /home/user/project",
      "HEAD abc123",
      "branch refs/heads/main",
      "",
      "worktree /home/user/project-wt",
      "HEAD def456",
      "branch refs/heads/feature",
    ].join("\n");
    assert.equal(findWorktreeForBranch(porcelain, "main"), "/home/user/project");
    assert.equal(findWorktreeForBranch(porcelain, "feature"), "/home/user/project-wt");
  });

  it("returns null for missing branch", () => {
    const porcelain = "worktree /path\nHEAD abc\nbranch refs/heads/main\n";
    assert.equal(findWorktreeForBranch(porcelain, "develop"), null);
  });
});

// ── executePlan ──────────────────────────────────────────────────────

describe("executePlan", () => {
  let dir: string;
  let origDir: string;
  let dirs: string[];

  beforeEach(() => {
    dirs = [];
    dir = realpathSync(mkdtempSync(join(tmpdir(), "exec-plan-")));
    dirs.push(dir);
    initRepo(dir);
    writeFileSync(join(dir, "seed.txt"), "seed\n");
    execSync("git add seed.txt && git commit -m seed", { cwd: dir, stdio: "ignore" });
    origDir = process.cwd();
    process.chdir(dir);
  });

  afterEach(() => {
    process.chdir(origDir);
    for (const d of dirs) {
      rmSync(d, { recursive: true, force: true });
    }
  });

  function track(dir: string): string {
    dirs.push(dir);
    return dir;
  }

  it("skips on action=skip", () => {
    const plan: HookPlan = { action: "skip" };
    const input = makeInput();
    const state = makeState(dir);
    const commitsBefore = execSync("git rev-list --count HEAD", { cwd: dir, encoding: "utf-8" }).trim();
    const result = executePlan(plan, input, state);
    const commitsAfter = execSync("git rev-list --count HEAD", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(result.exitCode, 0);
    assert.equal(commitsBefore, commitsAfter);
  });

  it("stages and commits a file", () => {
    const filePath = join(dir, "new.txt");
    writeFileSync(filePath, "new content\n");
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write new.txt",
        body: null,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput({ tool_input: { file_path: filePath } });
    const state = makeState(dir);
    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);
    const status = execSync("git status --porcelain", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(status, "");
    const subject = execSync("git log -1 --format=%s", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(subject, "auto: write new.txt");
  });

  it("includes body with session in commit", () => {
    const filePath = join(dir, "body.txt");
    writeFileSync(filePath, "body content\n");
    const sessionId = "abcdef12-3456-7890-abcd-ef1234567890";
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto(abcdef12): write body.txt",
        body: `Session: ${sessionId}`,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput({ tool_input: { file_path: filePath }, session_id: sessionId });
    const state = makeState(dir);
    executePlan(plan, input, state);
    const body = execSync("git log -1 --format=%b", { cwd: dir, encoding: "utf-8" }).trim();
    assert.match(body, /Session: abcdef12/);
  });

  it("exits 0 when nothing staged", () => {
    // seed.txt is already committed and unchanged
    const filePath = join(dir, "seed.txt");
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write seed.txt",
        body: null,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput({ tool_input: { file_path: filePath } });
    const state = makeState(dir);
    const commitsBefore = execSync("git rev-list --count HEAD", { cwd: dir, encoding: "utf-8" }).trim();
    const result = executePlan(plan, input, state);
    const commitsAfter = execSync("git rev-list --count HEAD", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(result.exitCode, 0);
    assert.equal(commitsBefore, commitsAfter);
  });

  it("stages file deletions", () => {
    // Create and commit a file, then delete it from disk
    const filePath = join(dir, "to-delete.txt");
    writeFileSync(filePath, "delete me\n");
    execSync(`git add "${filePath}" && git commit -m "add to-delete"`, { cwd: dir, stdio: "ignore" });
    rmSync(filePath);

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [],
        filesToRemove: ["to-delete.txt"],
        subject: "auto: delete to-delete.txt",
        body: null,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput();
    const state = makeState(dir);
    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);
    // Verify file is gone from git
    const files = execSync("git ls-files", { cwd: dir, encoding: "utf-8" }).trim();
    assert.ok(!files.includes("to-delete.txt"));
  });

  it("completes a merge (commit-merge)", () => {
    const { remote, clone } = setupRepoWithRemote("merge");
    track(remote);
    track(clone);
    process.chdir(clone);

    // Create a second clone that will push a conflicting change
    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "merge-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "conflict.txt"), "version A\n");
    execSync("git add conflict.txt && git commit -m 'add A' && git push origin main", {
      cwd: clone2,
      stdio: "ignore",
    });

    // In clone1, create a conflicting file
    writeFileSync(join(clone, "conflict.txt"), "version B\n");
    execSync("git add conflict.txt && git commit -m 'add B'", { cwd: clone, stdio: "ignore" });

    // Start merge that will conflict
    try {
      execSync("git pull origin main --no-rebase", { cwd: clone, stdio: "ignore" });
    } catch {
      // expected conflict
    }

    // Resolve the conflict manually
    writeFileSync(join(clone, "conflict.txt"), "resolved\n");

    const filePath = join(clone, "conflict.txt");
    const plan: HookPlan = {
      action: "commit-merge",
      message: "auto: resolve merge conflict in conflict.txt",
      sync: null,
      clockIn: null,
    };
    const input = makeInput({ tool_input: { file_path: filePath } });
    const gitDir = execSync("git rev-parse --git-dir", { cwd: clone, encoding: "utf-8" }).trim();
    const state = makeState(clone, { gitDir, hasRemote: true, inMerge: true });

    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);
    // MERGE_HEAD should be gone
    assert.ok(!existsSync(join(gitDir, "MERGE_HEAD")));
  });

  it("returns git exit code on unresolved merge", () => {
    const { remote, clone } = setupRepoWithRemote("unresolved");
    track(remote);
    track(clone);
    process.chdir(clone);

    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "unresolved-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    // Create two conflicting files
    writeFileSync(join(clone2, "conflict1.txt"), "version A\n");
    writeFileSync(join(clone2, "conflict2.txt"), "version A\n");
    execSync("git add . && git commit -m 'add A' && git push origin main", {
      cwd: clone2,
      stdio: "ignore",
    });

    writeFileSync(join(clone, "conflict1.txt"), "version B\n");
    writeFileSync(join(clone, "conflict2.txt"), "version B\n");
    execSync("git add . && git commit -m 'add B'", { cwd: clone, stdio: "ignore" });

    try {
      execSync("git pull origin main --no-rebase", { cwd: clone, stdio: "ignore" });
    } catch {
      // expected conflict
    }

    // Only pass one file — the other remains unresolved so git commit fails
    const plan: HookPlan = {
      action: "commit-merge",
      message: "auto: resolve merge conflict",
      sync: null,
      clockIn: null,
    };
    const input = makeInput({ tool_input: { file_path: join(clone, "conflict1.txt") } });
    const gitDir = execSync("git rev-parse --git-dir", { cwd: clone, encoding: "utf-8" }).trim();
    const state = makeState(clone, { gitDir, hasRemote: true, inMerge: true });

    const result = executePlan(plan, input, state);
    assert.ok(result.exitCode !== 0);
  });

  it("stages and commits modified files (e.g. permission changes)", () => {
    // Make file executable
    execSync(`chmod +x "${join(dir, "seed.txt")}"`);

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: ["seed.txt"],
        filesToRemove: [],
        subject: "auto: update seed.txt",
        body: null,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput();
    const state = makeState(dir, { modifiedFiles: ["seed.txt"] });
    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);
    const status = execSync("git status --porcelain", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(status, "");
    const subject = execSync("git log -1 --format=%s", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(subject, "auto: update seed.txt");
  });

  it("enriches commit subject from transcript", () => {
    const filePath = join(dir, "enriched.txt");
    writeFileSync(filePath, "enriched\n");

    const transcriptPath = join(dir, "transcript.jsonl");
    writeFileSync(
      transcriptPath,
      jsonl({ type: "user", message: { role: "user", content: "Fix the login bug" } }),
    );

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write enriched.txt",
        body: null,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput({
      tool_input: { file_path: filePath },
      transcript_path: transcriptPath,
      session_id: "abcdef12-3456-7890-abcd-ef1234567890",
    });
    const state = makeState(dir, { relPath: "enriched.txt" });

    executePlan(plan, input, state);
    const subject = execSync("git log -1 --format=%s", { cwd: dir, encoding: "utf-8" }).trim();
    assert.match(subject, /Fix the login bug/);
  });

  it("uses default subject when transcript unreadable", () => {
    const filePath = join(dir, "fallback.txt");
    writeFileSync(filePath, "fallback\n");

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write fallback.txt",
        body: null,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput({
      tool_input: { file_path: filePath },
      transcript_path: "/nonexistent/transcript.jsonl",
    });
    const state = makeState(dir);

    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);
    const subject = execSync("git log -1 --format=%s", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(subject, "auto: write fallback.txt");
  });
});

// ── executeSync ──────────────────────────────────────────────────────

describe("executeSync", () => {
  let dirs: string[];
  let origDir: string;

  beforeEach(() => {
    dirs = [];
    origDir = process.cwd();
  });

  afterEach(() => {
    process.chdir(origDir);
    for (const d of dirs) {
      rmSync(d, { recursive: true, force: true });
    }
  });

  function track(dir: string): string {
    dirs.push(dir);
    return dir;
  }

  it("pulls and pushes to remote", () => {
    const { remote, clone } = setupRepoWithRemote("sync");
    track(remote);
    track(clone);

    process.chdir(clone);

    // Create a new commit in clone
    writeFileSync(join(clone, "new.txt"), "new\n");
    execSync("git add new.txt && git commit -m 'add new'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { targetBranch: "main", currentBranch: "main" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 0);

    // Verify commit is on remote
    const remoteLog = execSync("git log --oneline", { cwd: remote, encoding: "utf-8" });
    assert.match(remoteLog, /add new/);
  });

  it("retries push after rejection", () => {
    const { remote, clone } = setupRepoWithRemote("retry");
    track(remote);
    track(clone);

    // Create clone2 that pushes first
    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "retry-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "a.txt"), "from clone2\n");
    execSync("git add a.txt && git commit -m 'clone2 commit' && git push origin main", {
      cwd: clone2,
      stdio: "ignore",
    });

    // clone1 has a different commit (different file, so no conflict on pull)
    process.chdir(clone);
    writeFileSync(join(clone, "b.txt"), "from clone1\n");
    execSync("git add b.txt && git commit -m 'clone1 commit'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { targetBranch: "main", currentBranch: "main" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 0);

    // Both commits should be on remote
    const remoteLog = execSync("git log --oneline", { cwd: remote, encoding: "utf-8" });
    assert.match(remoteLog, /clone1 commit/);
    assert.match(remoteLog, /clone2 commit/);
  });

  it("returns exit 2 on merge conflict during pull", () => {
    const { remote, clone } = setupRepoWithRemote("conflict");
    track(remote);
    track(clone);

    // clone2 pushes a conflicting change
    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "conflict-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "shared.txt"), "version A\n");
    execSync("git add shared.txt && git commit -m 'A' && git push origin main", {
      cwd: clone2,
      stdio: "ignore",
    });

    // clone1 has a conflicting change on the same file
    process.chdir(clone);
    writeFileSync(join(clone, "shared.txt"), "version B\n");
    execSync("git add shared.txt && git commit -m 'B'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { targetBranch: "main", currentBranch: "main" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 2);
    assert.ok(result.stderr);
    assert.match(result.stderr, /TRUNK-SYNC CONFLICT/);
  });

  it("merges target branch on non-target worktree branch", () => {
    const { remote, clone } = setupRepoWithRemote("wt-merge");
    track(remote);
    track(clone);

    // Push a change from clone2 to main
    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "wt-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "from-main.txt"), "main change\n");
    execSync("git add from-main.txt && git commit -m 'main change' && git push origin main", {
      cwd: clone2,
      stdio: "ignore",
    });

    // clone1 is on a worktree branch
    process.chdir(clone);
    execSync("git checkout -b trunk-sync-wt", { cwd: clone, stdio: "ignore" });
    writeFileSync(join(clone, "wt-file.txt"), "worktree\n");
    execSync("git add wt-file.txt && git commit -m 'wt commit'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { targetBranch: "main", currentBranch: "trunk-sync-wt" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 0);

    // Verify the main change was merged into worktree branch
    const log = execSync("git log --oneline", { cwd: clone, encoding: "utf-8" });
    assert.match(log, /main change/);
  });

  it("updates local target branch after push", () => {
    const { remote, clone } = setupRepoWithRemote("local-update");
    track(remote);
    track(clone);

    process.chdir(clone);

    writeFileSync(join(clone, "update.txt"), "update\n");
    execSync("git add update.txt && git commit -m 'update'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { targetBranch: "main", currentBranch: "main" };
    executeSync(sync);

    // Local main ref should match origin/main
    const localRef = execSync("git rev-parse main", { cwd: clone, encoding: "utf-8" }).trim();
    const remoteRef = execSync("git rev-parse origin/main", { cwd: clone, encoding: "utf-8" }).trim();
    assert.equal(localRef, remoteRef);
  });
});

// ── amendWithTranscriptSnapshot (via executePlan) ────────────────────

describe("amendWithTranscriptSnapshot", () => {
  let dir: string;
  let origDir: string;
  let origHome: string | undefined;
  let tmpHome: string;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "snapshot-")));
    initRepo(dir);
    writeFileSync(join(dir, "seed.txt"), "seed\n");
    execSync("git add seed.txt && git commit -m seed", { cwd: dir, stdio: "ignore" });
    origDir = process.cwd();
    process.chdir(dir);

    origHome = process.env.HOME;
    tmpHome = realpathSync(mkdtempSync(join(tmpdir(), "home-")));
    process.env.HOME = tmpHome;
  });

  afterEach(() => {
    process.chdir(origDir);
    if (origHome !== undefined) {
      process.env.HOME = origHome;
    }
    rmSync(dir, { recursive: true, force: true });
    rmSync(tmpHome, { recursive: true, force: true });
  });

  it("snapshots transcript when commit-transcripts=true", () => {
    // Write config
    writeFileSync(join(tmpHome, ".trunk-sync"), "commit-transcripts=true\n");

    // Create transcript file
    const transcriptPath = join(tmpHome, "session.jsonl");
    writeFileSync(transcriptPath, jsonl({ type: "user", message: { role: "user", content: "task" } }));

    const filePath = join(dir, "snap.txt");
    writeFileSync(filePath, "snap content\n");

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write snap.txt",
        body: null,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput({
      tool_input: { file_path: filePath },
      transcript_path: transcriptPath,
      session_id: "abcdef12-3456-7890-abcd-ef1234567890",
    });
    const state = makeState(dir);

    executePlan(plan, input, state);

    // Check .transcripts/ exists in git tree
    const diffTree = execSync("git diff-tree --no-commit-id --name-only -r HEAD", {
      cwd: dir,
      encoding: "utf-8",
    });
    assert.match(diffTree, /\.transcripts\//);
  });

  it("skips snapshot when commit-transcripts=false", () => {
    // No config file → defaults to false

    const transcriptPath = join(tmpHome, "session.jsonl");
    writeFileSync(transcriptPath, jsonl({ type: "user", message: { role: "user", content: "task" } }));

    const filePath = join(dir, "no-snap.txt");
    writeFileSync(filePath, "content\n");

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write no-snap.txt",
        body: null,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput({
      tool_input: { file_path: filePath },
      transcript_path: transcriptPath,
      session_id: "abcdef12-3456-7890-abcd-ef1234567890",
    });
    const state = makeState(dir);

    executePlan(plan, input, state);

    assert.ok(!existsSync(join(dir, ".transcripts")));
  });

  it("skips snapshot when no transcript_path", () => {
    writeFileSync(join(tmpHome, ".trunk-sync"), "commit-transcripts=true\n");

    const filePath = join(dir, "no-path.txt");
    writeFileSync(filePath, "content\n");

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write no-path.txt",
        body: null,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput({ tool_input: { file_path: filePath } });
    const state = makeState(dir);

    executePlan(plan, input, state);

    assert.ok(!existsSync(join(dir, ".transcripts")));
  });

  it("continues on snapshot failure", () => {
    writeFileSync(join(tmpHome, ".trunk-sync"), "commit-transcripts=true\n");

    const filePath = join(dir, "fail-snap.txt");
    writeFileSync(filePath, "content\n");

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write fail-snap.txt",
        body: null,
      },
      sync: null,
      clockIn: null,
    };
    const input = makeInput({
      tool_input: { file_path: filePath },
      transcript_path: "/nonexistent/session.jsonl",
      session_id: "abcdef12-3456-7890-abcd-ef1234567890",
    });
    const state = makeState(dir);

    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);

    // Commit still created
    const subject = execSync("git log -1 --format=%s", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(subject, "auto: write fail-snap.txt");
  });
});

// ── Clock-in I/O ─────────────────────────────────────────────────────────

describe("clockIn", () => {
  let dir: string;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "ts-clockin-")));
    initRepo(dir);
    writeFileSync(join(dir, "init.txt"), "init\n");
    execSync("git add . && git commit -m init", { cwd: dir, stdio: "ignore" });
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("creates timeclock directory and writes valid timecard", () => {
    const plan: ClockInPlan = {
      timecardPath: ".trunk-sync/timeclock/test-session.json",
      timecard: {
        sessionId: "test-session",
        pid: process.pid,
        hostname: "test-host",
        clockedInAt: "2026-03-27T10:00:00.000Z",
        lastActiveAt: "2026-03-27T10:05:00.000Z",
        branch: "main",
        task: null,
      },
    };
    clockIn(dir, plan, "Fix the login bug");
    const filePath = join(dir, ".trunk-sync", "timeclock", "test-session.json");
    assert.ok(existsSync(filePath));
    const content = JSON.parse(readFileSync(filePath, "utf-8")) as Timecard;
    assert.equal(content.sessionId, "test-session");
    assert.equal(content.pid, process.pid);
    assert.equal(content.hostname, "test-host");
    assert.equal(content.task, "Fix the login bug");
  });

  it("preserves clockedInAt from existing timecard", () => {
    const plan: ClockInPlan = {
      timecardPath: ".trunk-sync/timeclock/test-session.json",
      timecard: {
        sessionId: "test-session",
        pid: process.pid,
        hostname: "test-host",
        clockedInAt: "2026-03-27T10:05:00.000Z",
        lastActiveAt: "2026-03-27T10:05:00.000Z",
        branch: "main",
        task: null,
      },
    };
    // Write first timecard
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "test-session.json"), JSON.stringify({
      sessionId: "test-session",
      pid: process.pid,
      hostname: "test-host",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:00:00.000Z",
      branch: "main",
      task: null,
    }));
    // Update timecard
    clockIn(dir, plan, null);
    const content = JSON.parse(readFileSync(join(timeclockDir, "test-session.json"), "utf-8")) as Timecard;
    assert.equal(content.clockedInAt, "2026-03-27T10:00:00.000Z");
    assert.equal(content.lastActiveAt, "2026-03-27T10:05:00.000Z");
  });
});

describe("readTimecards", () => {
  let dir: string;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "ts-clockin-")));
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("returns empty when no timeclock directory", () => {
    assert.deepEqual(readTimecards(dir), []);
  });

  it("reads multiple timecards", () => {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "a.json"), JSON.stringify({ sessionId: "a", pid: 1, hostname: "h", clockedInAt: "", lastActiveAt: "", branch: "main", task: null }));
    writeFileSync(join(timeclockDir, "b.json"), JSON.stringify({ sessionId: "b", pid: 2, hostname: "h", clockedInAt: "", lastActiveAt: "", branch: "main", task: null }));
    const timecards = readTimecards(dir);
    assert.equal(timecards.length, 2);
  });

  it("skips malformed files", () => {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "good.json"), JSON.stringify({ sessionId: "good", pid: 1, hostname: "h", clockedInAt: "", lastActiveAt: "", branch: "main", task: null }));
    writeFileSync(join(timeclockDir, "bad.json"), "not json");
    const timecards = readTimecards(dir);
    assert.equal(timecards.length, 1);
    assert.equal(timecards[0].sessionId, "good");
  });
});

describe("isProcessAlive", () => {
  it("returns true for own process", () => {
    assert.ok(isProcessAlive(process.pid));
  });

  it("returns false for non-existent process", () => {
    assert.ok(!isProcessAlive(999999999));
  });
});

describe("clockOutStale", () => {
  let dir: string;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "ts-prune-")));
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "stale-1.json"), "{}");
    writeFileSync(join(timeclockDir, "stale-2.json"), "{}");
    writeFileSync(join(timeclockDir, "keep.json"), "{}");
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("removes stale timecards and returns paths", () => {
    const removed = clockOutStale(dir, ["stale-1", "stale-2"]);
    assert.equal(removed.length, 2);
    assert.ok(!existsSync(join(dir, ".trunk-sync", "timeclock", "stale-1.json")));
    assert.ok(!existsSync(join(dir, ".trunk-sync", "timeclock", "stale-2.json")));
    assert.ok(existsSync(join(dir, ".trunk-sync", "timeclock", "keep.json")));
  });

  it("handles already-removed files", () => {
    const removed = clockOutStale(dir, ["nonexistent"]);
    assert.equal(removed.length, 0);
  });
});

describe("executePlan with clock-in", () => {
  let dir: string;
  let origDir: string;
  const origHome = process.env.HOME;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "ts-clockin-exec-")));
    initRepo(dir);
    writeFileSync(join(dir, "init.txt"), "init\n");
    execSync("git add . && git commit -m init", { cwd: dir, stdio: "ignore" });
    origDir = process.cwd();
    process.chdir(dir);
    process.env.HOME = mkdtempSync(join(tmpdir(), "ts-home-"));
  });

  afterEach(() => {
    process.chdir(origDir);
    rmSync(dir, { recursive: true, force: true });
    if (process.env.HOME && process.env.HOME !== origHome) {
      rmSync(process.env.HOME, { recursive: true, force: true });
    }
    process.env.HOME = origHome;
  });

  it("commits timecard alongside code change", () => {
    const filePath = join(dir, "code.txt");
    writeFileSync(filePath, "code\n");
    const clockInPlan: ClockInPlan = {
      timecardPath: ".trunk-sync/timeclock/my-session.json",
      timecard: {
        sessionId: "my-session",
        pid: process.pid,
        hostname: "test-host",
        clockedInAt: new Date().toISOString(),
        lastActiveAt: new Date().toISOString(),
        branch: "main",
        task: null,
      },
    };
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write code.txt",
        body: null,
      },
      sync: null,
      clockIn: clockInPlan,
    };
    const input = makeInput({ tool_input: { file_path: filePath } });
    const state = makeState(dir);
    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);

    // Timecard should be in the commit
    const files = execSync("git diff-tree --no-commit-id --name-only -r HEAD", { cwd: dir, encoding: "utf-8" }).trim();
    assert.ok(files.includes(".trunk-sync/timeclock/my-session.json"));
    assert.ok(files.includes("code.txt"));
  });

  it("returns exit 2 with clock-in message when other agents clocked in", () => {
    // Create another agent's timecard
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "other-session.json"), JSON.stringify({
      sessionId: "other-session",
      pid: process.pid, // use own PID so it appears alive
      hostname: "test-host",
      clockedInAt: new Date().toISOString(),
      lastActiveAt: new Date().toISOString(),
      branch: "feature",
      task: "Refactoring auth",
    }));
    execSync("git add . && git commit -m 'add other agent'", { cwd: dir, stdio: "ignore" });

    const filePath = join(dir, "code.txt");
    writeFileSync(filePath, "code\n");
    const clockInPlan: ClockInPlan = {
      timecardPath: ".trunk-sync/timeclock/my-session.json",
      timecard: {
        sessionId: "my-session",
        pid: process.pid,
        hostname: "test-host",
        clockedInAt: new Date().toISOString(),
        lastActiveAt: new Date().toISOString(),
        branch: "main",
        task: null,
      },
    };
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write code.txt",
        body: null,
      },
      sync: null,
      clockIn: clockInPlan,
    };
    const input = makeInput({ tool_input: { file_path: filePath } });
    const state = makeState(dir);

    // Clear any existing throttle
    const throttlePath = join(process.env.TMPDIR || "/tmp", "trunk-sync-clockin-my-session");
    try { unlinkSync(throttlePath); } catch { /* ignore */ }

    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 2, `expected exit 2, got ${result.exitCode}. stderr: ${result.stderr}`);
    assert.ok(result.stderr?.includes("TRUNK-SYNC CLOCK-IN"), `expected TRUNK-SYNC CLOCK-IN in: ${result.stderr}`);
    assert.ok(result.stderr?.includes("other-se"), `expected other-se in: ${result.stderr}`);
    assert.ok(result.stderr?.includes("Refactoring auth"));
    assert.ok(result.stderr?.includes("resource conflicts"));
  });

  it("suppresses clock-in message when throttle file is fresh", () => {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "other-session.json"), JSON.stringify({
      sessionId: "other-session",
      pid: process.pid,
      hostname: "test-host",
      clockedInAt: new Date().toISOString(),
      lastActiveAt: new Date().toISOString(),
      branch: "feature",
      task: "Some task",
    }));
    execSync("git add . && git commit -m 'add other agent'", { cwd: dir, stdio: "ignore" });

    const filePath = join(dir, "code.txt");
    writeFileSync(filePath, "code\n");
    const clockInPlan: ClockInPlan = {
      timecardPath: ".trunk-sync/timeclock/my-session.json",
      timecard: {
        sessionId: "my-session",
        pid: process.pid,
        hostname: "test-host",
        clockedInAt: new Date().toISOString(),
        lastActiveAt: new Date().toISOString(),
        branch: "main",
        task: null,
      },
    };
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write code.txt",
        body: null,
      },
      sync: null,
      clockIn: clockInPlan,
    };
    const input = makeInput({ tool_input: { file_path: filePath } });
    const state = makeState(dir);

    // Write a fresh throttle file (just now)
    const throttlePath = join(process.env.TMPDIR || "/tmp", "trunk-sync-clockin-my-session");
    writeFileSync(throttlePath, String(Date.now()));

    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0, `expected exit 0 (throttled), got ${result.exitCode}. stderr: ${result.stderr}`);
    assert.ok(!result.stderr?.includes("TRUNK-SYNC CLOCK-IN"), `expected no CLOCK-IN message when throttled`);

    unlinkSync(throttlePath);
  });

  it("clocks out agents with dead PIDs", () => {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "dead-session.json"), JSON.stringify({
      sessionId: "dead-session",
      pid: 999999999, // dead PID
      hostname: hostname(), // local hostname
      clockedInAt: new Date().toISOString(),
      lastActiveAt: new Date().toISOString(),
      branch: "main",
      task: null,
    }));
    execSync("git add . && git commit -m 'add dead agent'", { cwd: dir, stdio: "ignore" });

    const filePath = join(dir, "code.txt");
    writeFileSync(filePath, "code\n");
    const clockInPlan: ClockInPlan = {
      timecardPath: ".trunk-sync/timeclock/my-session.json",
      timecard: {
        sessionId: "my-session",
        pid: process.pid,
        hostname: hostname(),
        clockedInAt: new Date().toISOString(),
        lastActiveAt: new Date().toISOString(),
        branch: "main",
        task: null,
      },
    };
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write code.txt",
        body: null,
      },
      sync: null,
      clockIn: clockInPlan,
    };
    const input = makeInput({ tool_input: { file_path: filePath } });
    const state = makeState(dir);
    executePlan(plan, input, state);

    // Dead agent's timecard should be removed
    assert.ok(!existsSync(join(timeclockDir, "dead-session.json")));
    // Own timecard should exist
    assert.ok(existsSync(join(timeclockDir, "my-session.json")));
  });
});
