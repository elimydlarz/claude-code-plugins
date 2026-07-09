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
import type { HookInput, RepoState, HookPlan, SyncPlan, Timecard } from "./hook-types.js";
import { gatherRepoState, getRuntimeContext, findWorktreeForBranch, executePlan, executeSync, clockIn, readTimecards, reapCards, runSessionStart, runStop } from "./hook-execute.js";

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
    untrackedFiles: [],
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
    // `git rev-parse --git-dir` reports relative to cwd — ".git" when cwd is the repo root.
    assert.equal(state.gitDir, ".git");
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

  it("reports current branch name", () => {
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.currentBranch, "main");
  });

  it("reports empty currentBranch in detached HEAD", () => {
    const sha = execSync("git rev-parse HEAD", { cwd: dir, encoding: "utf-8" }).trim();
    execSync(`git checkout --detach ${sha}`, { cwd: dir, stdio: "ignore" });
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.currentBranch, "");
  });

  it("detects no remote", () => {
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.hasRemote, false);
  });

  it("defaults targetBranch to agents when no override is configured", () => {
    const { clone } = setupRepoWithRemote("gather-remote");
    const origDir = process.cwd();
    process.chdir(clone);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.hasRemote, true);
    assert.equal(state.targetBranch, "agents");
    rmSync(clone, { recursive: true, force: true });
  });

  it("reads targetBranch from .trunk-sync/config when target-branch is set", () => {
    const { clone } = setupRepoWithRemote("gather-remote-override");
    mkdirSync(join(clone, ".trunk-sync"), { recursive: true });
    writeFileSync(join(clone, ".trunk-sync", "config"), "target-branch=develop\n");
    const origDir = process.cwd();
    process.chdir(clone);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.targetBranch, "develop");
    rmSync(clone, { recursive: true, force: true });
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

  it("detects untracked new files when no file_path", () => {
    writeFileSync(join(dir, "brand-new.txt"), "new\n");
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.deepEqual(state.untrackedFiles, ["brand-new.txt"]);
  });

  it("excludes gitignored untracked files", () => {
    writeFileSync(join(dir, ".gitignore"), "*.log\n");
    execSync("git add .gitignore && git commit -m gitignore", { cwd: dir, stdio: "ignore" });
    writeFileSync(join(dir, "debug.log"), "ignored\n");
    writeFileSync(join(dir, "keep.txt"), "kept\n");
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.deepEqual(state.untrackedFiles, ["keep.txt"]);
  });

  it("does not detect modified or untracked files when file_path is provided", () => {
    writeFileSync(join(dir, "file.txt"), "modified\n");
    writeFileSync(join(dir, "brand-new.txt"), "new\n");
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(
      makeInput({ tool_input: { file_path: join(dir, "file.txt") } }),
    );
    process.chdir(origDir);
    assert.ok(state);
    assert.deepEqual(state.modifiedFiles, []);
    assert.deepEqual(state.untrackedFiles, []);
  });

  it("reports a merge in progress via MERGE_HEAD", () => {
    writeFileSync(join(dir, ".git", "MERGE_HEAD"), "0".repeat(40) + "\n");
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.inMerge, true);
  });

  it("reports no merge in progress when MERGE_HEAD is absent", () => {
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.inMerge, false);
  });

  it("reports staged changes", () => {
    writeFileSync(join(dir, "file.txt"), "staged change\n");
    execSync("git add file.txt", { cwd: dir });
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.hasStagedChanges, true);
  });

  it("reports no staged changes when the index is clean", () => {
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.equal(state.hasStagedChanges, false);
  });
});

// ── getRuntimeContext ────────────────────────────────────────────────

describe("getRuntimeContext", () => {
  it("reports the host machine's hostname", () => {
    const ctx = getRuntimeContext();
    assert.equal(ctx.hostname, hostname());
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

  it("stages repo-root-relative files when the hook runs from a subdirectory", () => {
    mkdirSync(join(dir, "nested"));
    process.chdir(join(dir, "nested"));
    writeFileSync(join(dir, "root-file.txt"), "created from nested cwd\n");

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: ["root-file.txt"],
        filesToRemove: [],
        subject: "auto: update root-file.txt",
        body: null,
      },
      sync: null,
    };
    const input = makeInput();
    const state = makeState(dir, { untrackedFiles: ["root-file.txt"] });

    const result = executePlan(plan, input, state);

    assert.equal(result.exitCode, 0);
    const committed = execSync("git show --name-only --format= HEAD", {
      cwd: dir,
      encoding: "utf-8",
    }).trim();
    assert.equal(committed, "root-file.txt");
    const status = execSync("git status --porcelain", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(status, "");
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

  it("returns exit 2 with push-failure feedback when the retried push also fails", () => {
    const { remote, clone } = setupRepoWithRemote("push-fail");
    track(remote);
    track(clone);

    // A pre-receive hook that unconditionally rejects every push, so both the
    // initial push and the retry push fail.
    const hooksDir = join(remote, "hooks");
    mkdirSync(hooksDir, { recursive: true });
    writeFileSync(join(hooksDir, "pre-receive"), "#!/bin/sh\necho 'rejected by policy' >&2\nexit 1\n");
    execSync(`chmod +x "${join(hooksDir, "pre-receive")}"`);

    process.chdir(clone);
    writeFileSync(join(clone, "new.txt"), "new\n");
    execSync("git add new.txt && git commit -m 'add new'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { targetBranch: "main", currentBranch: "main" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 2);
    assert.ok(result.stderr);
    assert.match(result.stderr, /TRUNK-SYNC FAILED/);
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

  it("creates the target branch on first sync when it doesn't exist on the remote yet", () => {
    const { remote, clone } = setupRepoWithRemote("fresh-branch");
    track(remote);
    track(clone);

    process.chdir(clone);
    writeFileSync(join(clone, "new.txt"), "new\n");
    execSync("git add new.txt && git commit -m 'add new'", { cwd: clone, stdio: "ignore" });

    // currentBranch "main" (local default), targetBranch "agents" (never pushed before) —
    // the realistic first-sync shape under the new default target branch.
    const sync: SyncPlan = { targetBranch: "agents", currentBranch: "main" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 0);

    const remoteLog = execSync("git log --oneline agents", { cwd: remote, encoding: "utf-8" });
    assert.match(remoteLog, /add new/);
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

  it("returns exit 2 with conflict feedback when merging the local target branch into the worktree branch conflicts", () => {
    const { remote, clone } = setupRepoWithRemote("wt-local-conflict");
    track(remote);
    track(clone);

    process.chdir(clone);
    // Local-only commit on main, never pushed — this is what the second merge
    // step (local target branch → worktree branch) must reconcile.
    writeFileSync(join(clone, "shared.txt"), "local main content\n");
    execSync("git add shared.txt && git commit -m 'local main only'", { cwd: clone, stdio: "ignore" });

    // Branch off the point before that local commit, with a conflicting change to the same file
    execSync("git checkout -b trunk-sync-wt HEAD~1", { cwd: clone, stdio: "ignore" });
    writeFileSync(join(clone, "shared.txt"), "worktree content\n");
    execSync("git add shared.txt && git commit -m 'wt commit'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { targetBranch: "main", currentBranch: "trunk-sync-wt" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 2);
    assert.ok(result.stderr);
    assert.match(result.stderr, /TRUNK-SYNC CONFLICT/);
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

  it("fast-forwards the local target branch in its own worktree when fetch cannot update it directly", () => {
    const { remote, clone } = setupRepoWithRemote("wt-ff-fallback");
    track(remote);
    track(clone);

    process.chdir(clone);
    execSync("git checkout -b trunk-sync-wt", { cwd: clone, stdio: "ignore" });

    // Check main out into its own worktree, so a direct `git fetch main:main`
    // cannot update it (git refuses to move a ref checked out elsewhere).
    const mainWtParent = mkdtempSync(join(tmpdir(), "wt-ff-fallback-mainwt-"));
    const mainWt = realpathSync(mainWtParent);
    rmSync(mainWt, { recursive: true, force: true });
    track(mainWt);
    execSync(`git worktree add "${mainWt}" main`, { cwd: clone, stdio: "ignore" });

    writeFileSync(join(clone, "wt-only.txt"), "from worktree branch\n");
    execSync("git add wt-only.txt && git commit -m 'wt commit'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { targetBranch: "main", currentBranch: "trunk-sync-wt" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 0);

    const remoteLog = execSync("git log --oneline main", { cwd: remote, encoding: "utf-8" });
    assert.match(remoteLog, /wt commit/);

    // The separate main worktree must have been fast-forwarded, since fetch
    // could not update the "main" ref directly while it was checked out there.
    const mainWtLog = execSync("git log --oneline", { cwd: mainWt, encoding: "utf-8" });
    assert.match(mainWtLog, /wt commit/);
  });
});

// ── amendWithTranscriptSnapshot (via executePlan) ────────────────────

describe("amendWithTranscriptSnapshot", () => {
  let dir: string;
  let origDir: string;
  let scratch: string;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "snapshot-")));
    initRepo(dir);
    writeFileSync(join(dir, "seed.txt"), "seed\n");
    execSync("git add seed.txt && git commit -m seed", { cwd: dir, stdio: "ignore" });
    origDir = process.cwd();
    process.chdir(dir);

    scratch = realpathSync(mkdtempSync(join(tmpdir(), "scratch-")));
  });

  afterEach(() => {
    process.chdir(origDir);
    rmSync(dir, { recursive: true, force: true });
    rmSync(scratch, { recursive: true, force: true });
  });

  function writeRepoConfig(content: string): void {
    mkdirSync(join(dir, ".trunk-sync"), { recursive: true });
    writeFileSync(join(dir, ".trunk-sync", "config"), content);
  }

  it("snapshots transcript when commit-transcripts=true", () => {
    writeRepoConfig("commit-transcripts=true\n");

    // Create transcript file
    const transcriptPath = join(scratch, "session.jsonl");
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
    writeRepoConfig("commit-transcripts=false\n");

    const transcriptPath = join(scratch, "session.jsonl");
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

  it("does not snapshot by default when commit-transcripts is unset", () => {
    // No config file → defaults to OFF
    const transcriptPath = join(scratch, "session.jsonl");
    writeFileSync(transcriptPath, jsonl({ type: "user", message: { role: "user", content: "task" } }));

    const filePath = join(dir, "default-snap.txt");
    writeFileSync(filePath, "content\n");

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write default-snap.txt",
        body: null,
      },
      sync: null,
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
    writeRepoConfig("commit-transcripts=true\n");

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
    };
    const input = makeInput({ tool_input: { file_path: filePath } });
    const state = makeState(dir);

    executePlan(plan, input, state);

    assert.ok(!existsSync(join(dir, ".transcripts")));
  });

  it("skips snapshot when no session_id", () => {
    writeRepoConfig("commit-transcripts=true\n");

    const transcriptPath = join(scratch, "session.jsonl");
    writeFileSync(transcriptPath, jsonl({ type: "user", message: { role: "user", content: "task" } }));

    const filePath = join(dir, "no-session.txt");
    writeFileSync(filePath, "content\n");

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write no-session.txt",
        body: null,
      },
      sync: null,
    };
    const input = makeInput({ tool_input: { file_path: filePath }, transcript_path: transcriptPath });
    const state = makeState(dir);

    executePlan(plan, input, state);

    assert.ok(!existsSync(join(dir, ".transcripts")));
  });

  it("continues on snapshot failure", () => {
    writeRepoConfig("commit-transcripts=true\n");

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
    const timecard: Timecard = {
      sessionId: "test-session", hostname: "test-host",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:05:00.000Z",
      branch: "main",
    };
    clockIn(dir, timecard);
    const filePath = join(dir, ".trunk-sync", "timeclock", "test-session.json");
    assert.ok(existsSync(filePath));
    const content = JSON.parse(readFileSync(filePath, "utf-8")) as Timecard;
    assert.equal(content.sessionId, "test-session");
    assert.equal(content.hostname, "test-host");
    assert.equal("task" in content, false);
  });

  it("preserves clockedInAt from existing timecard", () => {
    const timecard: Timecard = {
      sessionId: "test-session", hostname: "test-host",
      clockedInAt: "2026-03-27T10:05:00.000Z",
      lastActiveAt: "2026-03-27T10:05:00.000Z",
      branch: "main",
    };
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "test-session.json"), JSON.stringify({
      sessionId: "test-session", hostname: "test-host",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:00:00.000Z",
      branch: "main",
    }));
    clockIn(dir, timecard);
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
    writeFileSync(join(timeclockDir, "a.json"), JSON.stringify({ sessionId: "a", hostname: "h", clockedInAt: "", lastActiveAt: "", branch: "main" }));
    writeFileSync(join(timeclockDir, "b.json"), JSON.stringify({ sessionId: "b", hostname: "h", clockedInAt: "", lastActiveAt: "", branch: "main" }));
    const timecards = readTimecards(dir);
    assert.equal(timecards.length, 2);
  });

  it("skips malformed files", () => {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "good.json"), JSON.stringify({ sessionId: "good", hostname: "h", clockedInAt: "", lastActiveAt: "", branch: "main" }));
    writeFileSync(join(timeclockDir, "bad.json"), "not json");
    const timecards = readTimecards(dir);
    assert.equal(timecards.length, 1);
    assert.equal(timecards[0].sessionId, "good");
  });
});

describe("runSessionStart", () => {
  let dir: string;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "ts-sessionstart-")));
    initRepo(dir);
    writeFileSync(join(dir, "seed.txt"), "seed\n");
    execSync("git add . && git commit -m seed", { cwd: dir, stdio: "ignore" });
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  function writeCard(card: Partial<Timecard> & { sessionId: string }): void {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    const full: Timecard = {
      hostname: "remote-host", clockedInAt: new Date().toISOString(),
      lastActiveAt: new Date().toISOString(), branch: "main",
      ...card,
    };
    writeFileSync(join(timeclockDir, `${card.sessionId}.json`), JSON.stringify(full));
  }

  function start(sessionId: string | null): string | null {
    return runSessionStart(makeState(dir), sessionId, { hostname: "local-host" });
  }

  it("hands the starting agent its own session id", () => {
    const msg = start("my-session-id")!;
    assert.match(msg, /my-session-id/);
    assert.doesNotMatch(msg, /trunk-sync-progress/);
    assert.ok(existsSync(join(dir, ".trunk-sync", "timeclock", "my-session-id.json")));
  });

  it("appends the active roster when another agent is clocked in", () => {
    writeCard({ sessionId: "other-id" });
    const msg = start("my-session-id")!;
    assert.match(msg, /TRUNK-SYNC ACTIVE/);
    assert.match(msg, /other-id/);
    assert.doesNotMatch(msg, /task:/);
  });

  it("prints only the own-id instruction when no other agents are clocked in", () => {
    const msg = start("my-session-id")!;
    assert.match(msg, /my-session-id/);
    assert.doesNotMatch(msg, /TRUNK-SYNC ACTIVE/);
  });

  it("creates the timeclock directory when it does not exist", () => {
    const msg = start("my-session-id")!;
    assert.match(msg, /my-session-id/);
    assert.doesNotMatch(msg, /trunk-sync-progress/);
    assert.ok(existsSync(join(dir, ".trunk-sync", "timeclock")));
  });

  it("excludes the starting session's own timecard from the roster", () => {
    writeCard({ sessionId: "my-session-id" });
    const msg = start("my-session-id")!;
    assert.doesNotMatch(msg, /TRUNK-SYNC ACTIVE/);
  });

  it("returns null when there is no session id", () => {
    assert.equal(start(null), null);
    assert.ok(!existsSync(join(dir, ".trunk-sync", "timeclock")));
  });

  it("omits the roster when the only other card is past the reap ttl", () => {
    const reapableTime = new Date(Date.now() - 15 * 24 * 60 * 60 * 1000).toISOString();
    writeCard({ sessionId: "ghost-id", lastActiveAt: reapableTime });
    const msg = start("my-session-id")!;
    assert.match(msg, /my-session-id/);
    assert.doesNotMatch(msg, /TRUNK-SYNC ACTIVE/);
    assert.doesNotMatch(msg, /ghost-id/);
  });

  it("omits stale cards because timecards are presence only", () => {
    const staleTime = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
    writeCard({ sessionId: "stale-id", lastActiveAt: staleTime });
    const msg = start("my-session-id")!;
    assert.match(msg, /my-session-id/);
    assert.doesNotMatch(msg, /TRUNK-SYNC ACTIVE/);
    assert.doesNotMatch(msg, /stale-id/);
  });
});

describe("runStop", () => {
  let dir: string;
  let origDir: string;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "ts-stop-")));
    initRepo(dir);
    writeFileSync(join(dir, "seed.txt"), "seed\n");
    execSync("git add . && git commit -m seed", { cwd: dir, stdio: "ignore" });
    origDir = process.cwd();
    process.chdir(dir);
  });

  afterEach(() => {
    process.chdir(origDir);
    rmSync(dir, { recursive: true, force: true });
  });

  function writeCard(sessionId: string, lastActiveAt: string): string {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    const cardPath = join(timeclockDir, `${sessionId}.json`);
    writeFileSync(cardPath, JSON.stringify({
      sessionId, hostname: "h", clockedInAt: lastActiveAt, lastActiveAt,
      branch: "main",
    }));
    execSync("git add . && git commit -m 'add card'", { cwd: dir, stdio: "ignore" });
    return cardPath;
  }

  it("removes and commits the timecard when the session has a timecard", () => {
    const staleTime = new Date(Date.now() - 45 * 60 * 1000).toISOString();
    const cardPath = writeCard("my-session", staleTime);

    runStop(makeState(dir), "my-session");

    assert.ok(!existsSync(cardPath));
    const subject = execSync("git log -1 --format=%s", { cwd: dir, encoding: "utf-8" }).trim();
    assert.match(subject, /clock-out/);
  });

  it("creates no card and exits cleanly when the session has no timecard", () => {
    runStop(makeState(dir), "ghost-session");
    assert.ok(!existsSync(join(dir, ".trunk-sync", "timeclock", "ghost-session.json")));
  });

  it("does nothing when no session id is provided", () => {
    assert.doesNotThrow(() => runStop(makeState(dir), null));
  });

  it("pushes the removed timecard to the remote when a remote is configured", () => {
    const { remote, clone } = setupRepoWithRemote("stop-sync");
    process.chdir(clone);

    const staleTime = new Date(Date.now() - 45 * 60 * 1000).toISOString();
    const timeclockDir = join(clone, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "remote-session.json"), JSON.stringify({
      sessionId: "remote-session", hostname: "h", clockedInAt: staleTime, lastActiveAt: staleTime,
      branch: "main",
    }));
    execSync("git add . && git commit -m 'add card'", { cwd: clone, stdio: "ignore" });

    const state = makeState(clone, { hasRemote: true, targetBranch: "main", currentBranch: "main" });
    runStop(state, "remote-session");

    execSync("git fetch origin main", { cwd: clone, stdio: "ignore" });
    assert.throws(() => execSync("git show origin/main:.trunk-sync/timeclock/remote-session.json", { cwd: clone, stdio: "ignore" }));

    rmSync(remote, { recursive: true, force: true });
    rmSync(clone, { recursive: true, force: true });
  });

  it("never throws even when the post-clock-out sync fails — the stop hook always exits 0", () => {
    const { remote, clone } = setupRepoWithRemote("stop-sync-fail");
    process.chdir(clone);

    execSync(`git remote set-url origin "/nonexistent/path/to/remote.git"`, { cwd: clone });

    const staleTime = new Date(Date.now() - 45 * 60 * 1000).toISOString();
    const timeclockDir = join(clone, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "flaky-session.json"), JSON.stringify({
      sessionId: "flaky-session", hostname: "h", clockedInAt: staleTime, lastActiveAt: staleTime,
      branch: "main",
    }));
    execSync("git add . && git commit -m 'add card'", { cwd: clone, stdio: "ignore" });

    const state = makeState(clone, { hasRemote: true, targetBranch: "main", currentBranch: "main" });
    assert.doesNotThrow(() => runStop(state, "flaky-session"));

    assert.ok(!existsSync(join(timeclockDir, "flaky-session.json")));

    rmSync(remote, { recursive: true, force: true });
    rmSync(clone, { recursive: true, force: true });
  });
});

describe("reapCards", () => {
  let dir: string;

  beforeEach(() => {
    dir = realpathSync(mkdtempSync(join(tmpdir(), "ts-prune-")));
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "reap-1.json"), "{}");
    writeFileSync(join(timeclockDir, "reap-2.json"), "{}");
    writeFileSync(join(timeclockDir, "keep.json"), "{}");
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("removes each given card file and returns its path", () => {
    const removed = reapCards(dir, ["reap-1", "reap-2"]);
    assert.equal(removed.length, 2);
    assert.ok(!existsSync(join(dir, ".trunk-sync", "timeclock", "reap-1.json")));
    assert.ok(!existsSync(join(dir, ".trunk-sync", "timeclock", "reap-2.json")));
    assert.ok(existsSync(join(dir, ".trunk-sync", "timeclock", "keep.json")));
  });

  it("handles already-removed files gracefully", () => {
    const removed = reapCards(dir, ["nonexistent"]);
    assert.equal(removed.length, 0);
  });
});

describe("executePlan with timecard touch", () => {
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

  function writeOwnCard(sessionId = "my-session", lastActiveAt = new Date(Date.now() - 60_000).toISOString()): string {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    const cardPath = join(timeclockDir, `${sessionId}.json`);
    writeFileSync(cardPath, JSON.stringify({
      sessionId,
      hostname: hostname(),
      clockedInAt: lastActiveAt,
      lastActiveAt,
      branch: "main",
    }));
    execSync("git add . && git commit -m 'add own card'", { cwd: dir, stdio: "ignore" });
    return cardPath;
  }

  function commitAndSyncPlan(sessionId = "my-session"): { plan: HookPlan; input: HookInput; state: RepoState; filePath: string } {
    const filePath = join(dir, "code.txt");
    writeFileSync(filePath, "code\n");
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [filePath],
        filesToRemove: [],
        subject: "auto: write code.txt",
        body: null,
      },
      sync: null,
    };
    return { plan, input: makeInput({ session_id: sessionId, tool_input: { file_path: filePath } }), state: makeState(dir), filePath };
  }

  it("updates and commits an existing timecard alongside the code change", () => {
    const oldTime = new Date(Date.now() - 60_000).toISOString();
    const cardPath = writeOwnCard("my-session", oldTime);
    const { plan, input, state } = commitAndSyncPlan();
    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);

    const card = JSON.parse(readFileSync(cardPath, "utf-8")) as Timecard;
    assert.ok(new Date(card.lastActiveAt).getTime() > new Date(oldTime).getTime());
    const files = execSync("git diff-tree --no-commit-id --name-only -r HEAD", { cwd: dir, encoding: "utf-8" }).trim();
    assert.ok(files.includes(".trunk-sync/timeclock/my-session.json"));
    assert.ok(files.includes("code.txt"));
  });

  it("creates no timecard when the session has no timecard", () => {
    const { plan, input, state } = commitAndSyncPlan();
    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);
    assert.ok(!existsSync(join(dir, ".trunk-sync", "timeclock", "my-session.json")));
  });

  it("returns exit 2 with conflict feedback and active roster when sync conflicts", () => {
    const { remote, clone } = setupRepoWithRemote("touch-conflict");
    process.chdir(clone);
    dir = clone;
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    writeFileSync(join(timeclockDir, "other-session.json"), JSON.stringify({
      sessionId: "other-session", hostname: "test-host",
      clockedInAt: new Date().toISOString(),
      lastActiveAt: new Date().toISOString(),
      branch: "feature",
    }));
    writeOwnCard("my-session");
    writeFileSync(join(clone, "shared.txt"), "local\n");
    execSync("git add . && git commit -m 'local base'", { cwd: clone, stdio: "ignore" });
    execSync("git push origin main", { cwd: clone, stdio: "ignore" });

    const other = realpathSync(mkdtempSync(join(tmpdir(), "touch-conflict-other-")));
    execSync(`git clone "${remote}" .`, { cwd: other, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: other });
    execSync('git config user.name "Test"', { cwd: other });
    writeFileSync(join(other, "shared.txt"), "remote\n");
    execSync("git add shared.txt && git commit -m remote-change && git push origin main", { cwd: other, stdio: "ignore" });

    writeFileSync(join(clone, "shared.txt"), "conflicting local\n");
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        filesToStage: [join(clone, "shared.txt")],
        filesToRemove: [],
        subject: "auto: write shared.txt",
        body: null,
      },
      sync: { targetBranch: "main", currentBranch: "main" },
    };

    const input = makeInput({ session_id: "my-session", tool_input: { file_path: join(clone, "shared.txt") } });
    const state = makeState(clone, { hasRemote: true, targetBranch: "main", currentBranch: "main" });
    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 2);
    assert.match(result.stderr ?? "", /TRUNK-SYNC CONFLICT/);
    assert.match(result.stderr ?? "", /TRUNK-SYNC ACTIVE/);
    assert.match(result.stderr ?? "", /other-se/);

    rmSync(other, { recursive: true, force: true });
    rmSync(remote, { recursive: true, force: true });
  });

  it("reaps another agent's card once its heartbeat is past the reap ttl", () => {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    const twentyDaysAgo = new Date(Date.now() - 20 * 24 * 60 * 60 * 1000).toISOString();
    writeFileSync(join(timeclockDir, "abandoned.json"), JSON.stringify({
      sessionId: "abandoned", hostname: "other-host",
      clockedInAt: twentyDaysAgo, lastActiveAt: twentyDaysAgo,
      branch: "main",
    }));
    execSync("git add . && git commit -m 'add abandoned agent'", { cwd: dir, stdio: "ignore" });

    writeOwnCard("my-session");
    const { plan, input, state } = commitAndSyncPlan();
    executePlan(plan, input, state);

    assert.ok(!existsSync(join(timeclockDir, "abandoned.json")), "card past the TTL should be reaped");
    assert.ok(existsSync(join(timeclockDir, "my-session.json")));
  });

  it("preserves another agent's card whose heartbeat is within the reap ttl", () => {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();
    writeFileSync(join(timeclockDir, "stale-but-kept.json"), JSON.stringify({
      sessionId: "stale-but-kept", hostname: "other-host",
      clockedInAt: twoDaysAgo, lastActiveAt: twoDaysAgo,
      branch: "main",
    }));
    execSync("git add . && git commit -m 'add stale agent'", { cwd: dir, stdio: "ignore" });

    writeOwnCard("my-session");
    const { plan, input, state } = commitAndSyncPlan();
    executePlan(plan, input, state);

    assert.ok(existsSync(join(timeclockDir, "stale-but-kept.json")), "card within the TTL is preserved");
  });

});
