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
import { execSync, spawn } from "node:child_process";
import type { HookInput, RepoState, HookPlan, SyncPlan, Timecard } from "./hook-types.js";
import { gatherRepoState, getRuntimeContext, executePlan, executeSync, clockIn, readTimecards, reapCards, runSessionStart, runStop } from "./hook-execute.js";
import { planHook } from "./hook-plan.js";


/** Returns the Git output carried inside the do-not-follow tag, or null when it is absent. */
function taggedGitOutput(stderr: string | undefined): string | null {
  const match = (stderr ?? "").match(
    /<original git error message: do not follow advice>\n([\s\S]*?)\n<\/original git error message>/,
  );
  return match ? match[1] : null;
}

function initRepo(dir: string): void {
  execSync("git init", { cwd: dir, stdio: "ignore" });
  execSync('git config user.email "test@test.com"', { cwd: dir });
  execSync('git config user.name "Test"', { cwd: dir });
}

function makeInput(overrides: Partial<HookInput> = {}): HookInput {
  return {
    tool_name: "Write",
    tool_input: {},
    turn_id: null,
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
    currentBranch: "main",
    inMerge: false,
    deletedFiles: [],
    modifiedFiles: [],
    untrackedFiles: [],
    ...overrides,
  };
}

function setupRepoWithRemote(prefix: string): {
  remote: string;
  clone: string;
} {
  const remote = realpathSync(mkdtempSync(join(tmpdir(), `${prefix}-remote-`)));
  execSync("git init --bare", { cwd: remote, stdio: "ignore" });

  const clone = realpathSync(mkdtempSync(join(tmpdir(), `${prefix}-clone-`)));
  execSync(`git clone "${remote}" .`, { cwd: clone, stdio: "ignore" });
  execSync('git config user.email "test@test.com"', { cwd: clone });
  execSync('git config user.name "Test"', { cwd: clone });

  writeFileSync(join(clone, "init.txt"), "init\n");
  execSync("git add init.txt && git commit -m init", { cwd: clone, stdio: "ignore" });
  execSync("git push origin main", { cwd: clone, stdio: "ignore" });

  return { remote, clone };
}

function jsonl(...objects: unknown[]): string {
  return objects.map((o) => JSON.stringify(o)).join("\n");
}


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
    writeFileSync(join(dir, "file.txt"), "modified\n");
    const origDir = process.cwd();
    process.chdir(dir);
    const state = gatherRepoState(makeInput());
    process.chdir(origDir);
    assert.ok(state);
    assert.deepEqual(state.modifiedFiles, ["file.txt"]);
  });

  it("excludes unresolved paths retaining conflict markers or matching a conflict side until resolved", () => {
    execSync("git checkout -b other", { cwd: dir, stdio: "ignore" });
    writeFileSync(join(dir, "file.txt"), "other\n");
    execSync("git add file.txt && git commit -m other", { cwd: dir, stdio: "ignore" });
    execSync("git checkout main", { cwd: dir, stdio: "ignore" });
    writeFileSync(join(dir, "file.txt"), "main\n");
    execSync("git add file.txt && git commit -m main", { cwd: dir, stdio: "ignore" });
    assert.throws(() => execSync("git merge other", { cwd: dir, stdio: "ignore" }));

    const origDir = process.cwd();
    process.chdir(dir);
    const unresolved = gatherRepoState(makeInput({ tool_name: "apply_patch" }));
    writeFileSync(join(dir, "file.txt"), "resolved\n");
    const resolved = gatherRepoState(makeInput({ tool_name: "apply_patch" }));
    process.chdir(origDir);

    assert.ok(unresolved);
    assert.ok(resolved);
    assert.deepEqual(unresolved.modifiedFiles, []);
    assert.deepEqual(resolved.modifiedFiles, ["file.txt"]);

    const markerlessDir = realpathSync(mkdtempSync(join(tmpdir(), "gather-markerless-")));
    try {
      initRepo(markerlessDir);
      writeFileSync(join(markerlessDir, "file.txt"), "base\n");
      execSync("git add file.txt && git commit -m base", { cwd: markerlessDir, stdio: "ignore" });
      execSync("git checkout -b modified", { cwd: markerlessDir, stdio: "ignore" });
      writeFileSync(join(markerlessDir, "file.txt"), "modified\n");
      execSync("git add file.txt && git commit -m modified", { cwd: markerlessDir, stdio: "ignore" });
      execSync("git checkout main", { cwd: markerlessDir, stdio: "ignore" });
      rmSync(join(markerlessDir, "file.txt"));
      execSync("git add -A && git commit -m deleted", { cwd: markerlessDir, stdio: "ignore" });
      assert.throws(() => execSync("git merge modified", { cwd: markerlessDir, stdio: "ignore" }));

      process.chdir(markerlessDir);
      const matchingSide = gatherRepoState(makeInput({ tool_name: "apply_patch" }));
      process.chdir(origDir);

      assert.ok(matchingSide);
      assert.deepEqual(matchingSide.modifiedFiles, []);
    } finally {
      process.chdir(origDir);
      rmSync(markerlessDir, { recursive: true, force: true });
    }
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

});


describe("getRuntimeContext", () => {
  it("reports the host machine's hostname", () => {
    const ctx = getRuntimeContext();
    assert.equal(ctx.hostname, hostname());
  });
});


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
        changedPaths: ["new.txt"],
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
        changedPaths: ["body.txt"],
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
    const filePath = join(dir, "seed.txt");
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        changedPaths: ["seed.txt"],
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
    const filePath = join(dir, "to-delete.txt");
    writeFileSync(filePath, "delete me\n");
    execSync(`git add "${filePath}" && git commit -m "add to-delete"`, { cwd: dir, stdio: "ignore" });
    rmSync(filePath);

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        changedPaths: ["to-delete.txt"],
        subject: "auto: delete to-delete.txt",
        body: null,
      },
      sync: null,
    };
    const input = makeInput();
    const state = makeState(dir);
    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);
    const files = execSync("git ls-files", { cwd: dir, encoding: "utf-8" }).trim();
    assert.ok(!files.includes("to-delete.txt"));
  });

  it("completes a merge and records session and agent provenance on the merge commit", () => {
    const { remote, clone } = setupRepoWithRemote("merge");
    track(remote);
    track(clone);
    process.chdir(clone);

    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "merge-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "conflict.txt"), "version A\n");
    execSync("git add conflict.txt && git commit -m 'add A' && git push origin main", {
      cwd: clone2,
      stdio: "ignore",
    });

    writeFileSync(join(clone, "conflict.txt"), "version B\n");
    execSync("git add conflict.txt && git commit -m 'add B'", { cwd: clone, stdio: "ignore" });

    try {
      execSync("git pull origin main --no-rebase", { cwd: clone, stdio: "ignore" });
    } catch {
    }

    writeFileSync(join(clone, "conflict.txt"), "resolved\n");

    const filePath = join(clone, "conflict.txt");
    const plan: HookPlan = {
      action: "commit-merge",
      commit: {
        changedPaths: ["conflict.txt"],
        subject: "auto(merge-se): resolve merge conflict in conflict.txt",
        body: "Session: merge-session\nAgent: claude",
      },
      sync: null,
    };
    const input = makeInput({ tool_input: { file_path: filePath }, session_id: "merge-session" });
    const gitDir = execSync("git rev-parse --git-dir", { cwd: clone, encoding: "utf-8" }).trim();
    const state = makeState(clone, { gitDir, hasRemote: true, inMerge: true });

    const result = executePlan(plan, input, state);
    assert.equal(result.exitCode, 0);
    assert.ok(!existsSync(join(gitDir, "MERGE_HEAD")));
    const body = execSync("git log -1 --format=%b", { cwd: clone, encoding: "utf-8" }).trim();
    assert.equal(body, "Session: merge-session\nAgent: claude");
  });

  it("keeps a Claude merge open when its file_path retains conflict markers or matches a conflict side", () => {
    const { remote, clone } = setupRepoWithRemote("claude-unresolved-merge");
    track(remote);
    track(clone);
    process.chdir(clone);
    const other = track(realpathSync(mkdtempSync(join(tmpdir(), "claude-unresolved-other-"))));
    execSync(`git clone "${remote}" .`, { cwd: other, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: other });
    execSync('git config user.name "Test"', { cwd: other });
    writeFileSync(join(other, "conflict.txt"), "remote\n");
    execSync("git add conflict.txt && git commit -m remote && git push origin main", { cwd: other, stdio: "ignore" });
    writeFileSync(join(clone, "conflict.txt"), "local\n");
    execSync("git add conflict.txt && git commit -m local", { cwd: clone, stdio: "ignore" });
    assert.throws(() => execSync("git pull origin main --no-rebase", { cwd: clone, stdio: "ignore" }));

    const filePath = join(clone, "conflict.txt");
    const input = makeInput({ tool_name: "Edit", tool_input: { file_path: filePath }, session_id: "claude-partial" });
    const state = gatherRepoState(input);
    assert.ok(state);
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-merge");
    const headBefore = execSync("git rev-parse HEAD", { cwd: clone, encoding: "utf-8" }).trim();

    const result = executePlan(plan, input, state);

    assert.equal(result.exitCode, 2);
    assert.match(result.stderr ?? "", /conflict\.txt/);
    assert.match(result.stderr ?? "", /marker-based or markerless/);
    assert.equal(execSync("git rev-parse HEAD", { cwd: clone, encoding: "utf-8" }).trim(), headBefore);
    assert.ok(existsSync(join(state.gitDir, "MERGE_HEAD")));
    assert.equal(execSync("git diff --name-only --diff-filter=U", { cwd: clone, encoding: "utf-8" }).trim(), "conflict.txt");

    const markerlessDir = track(realpathSync(mkdtempSync(join(tmpdir(), "claude-markerless-"))));
    initRepo(markerlessDir);
    writeFileSync(join(markerlessDir, "file.txt"), "base\n");
    execSync("git add file.txt && git commit -m base", { cwd: markerlessDir, stdio: "ignore" });
    execSync("git checkout -b modified", { cwd: markerlessDir, stdio: "ignore" });
    writeFileSync(join(markerlessDir, "file.txt"), "modified\n");
    execSync("git add file.txt && git commit -m modified", { cwd: markerlessDir, stdio: "ignore" });
    execSync("git checkout main", { cwd: markerlessDir, stdio: "ignore" });
    rmSync(join(markerlessDir, "file.txt"));
    execSync("git add -A && git commit -m deleted", { cwd: markerlessDir, stdio: "ignore" });
    assert.throws(() => execSync("git merge modified", { cwd: markerlessDir, stdio: "ignore" }));
    process.chdir(markerlessDir);

    const markerlessInput = makeInput({
      tool_name: "Edit",
      tool_input: { file_path: join(markerlessDir, "file.txt") },
      session_id: "claude-markerless",
    });
    const markerlessState = gatherRepoState(markerlessInput);
    assert.ok(markerlessState);
    const markerlessPlan = planHook(markerlessInput, markerlessState);
    const markerlessHead = execSync("git rev-parse HEAD", { cwd: markerlessDir, encoding: "utf-8" }).trim();

    const markerlessResult = executePlan(markerlessPlan, markerlessInput, markerlessState);

    assert.equal(markerlessResult.exitCode, 2);
    assert.match(markerlessResult.stderr ?? "", /file\.txt/);
    assert.match(markerlessResult.stderr ?? "", /marker-based or markerless/);
    assert.equal(execSync("git rev-parse HEAD", { cwd: markerlessDir, encoding: "utf-8" }).trim(), markerlessHead);
    assert.equal(execSync("git diff --name-only --diff-filter=U", { cwd: markerlessDir, encoding: "utf-8" }).trim(), "file.txt");
  });

  it("completes a Codex merge without file_path", () => {
    const { remote, clone } = setupRepoWithRemote("codex-merge");
    track(remote);
    track(clone);
    process.chdir(clone);
    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "codex-merge-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "conflict.txt"), "remote\n");
    execSync("git add conflict.txt && git commit -m remote && git push origin main", { cwd: clone2, stdio: "ignore" });
    writeFileSync(join(clone, "conflict.txt"), "local\n");
    execSync("git add conflict.txt && git commit -m local", { cwd: clone, stdio: "ignore" });
    assert.throws(() => execSync("git pull origin main --no-rebase", { cwd: clone, stdio: "ignore" }));
    writeFileSync(join(clone, "conflict.txt"), "resolved\n");
    const plan: HookPlan = {
      action: "commit-merge",
      commit: {
        changedPaths: ["conflict.txt"],
        subject: "auto(codex-me): resolve merge conflict in conflict.txt",
        body: "Session: codex-merge\nAgent: codex",
      },
      sync: null,
    };
    const input = makeInput({ tool_name: "apply_patch", session_id: "codex-merge" });
    const gitDir = execSync("git rev-parse --git-dir", { cwd: clone, encoding: "utf-8" }).trim();

    const result = executePlan(plan, input, makeState(clone, { gitDir, inMerge: true }));

    assert.equal(result.exitCode, 0);
    assert.ok(!existsSync(join(gitDir, "MERGE_HEAD")));
    assert.equal(readFileSync(join(clone, "conflict.txt"), "utf-8"), "resolved\n");
  });

  it("keeps unresolved Codex merge paths open when only some conflicts are resolved", () => {
    const { remote, clone } = setupRepoWithRemote("codex-partial-merge");
    track(remote);
    track(clone);
    process.chdir(clone);
    const other = track(realpathSync(mkdtempSync(join(tmpdir(), "codex-partial-merge-other-"))));
    execSync(`git clone "${remote}" .`, { cwd: other, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: other });
    execSync('git config user.name "Test"', { cwd: other });
    for (const name of ["one.txt", "two.txt"]) writeFileSync(join(other, name), "remote\n");
    execSync("git add . && git commit -m remote && git push origin main", { cwd: other, stdio: "ignore" });
    for (const name of ["one.txt", "two.txt"]) writeFileSync(join(clone, name), "local\n");
    execSync("git add . && git commit -m local", { cwd: clone, stdio: "ignore" });
    assert.throws(() => execSync("git pull origin main --no-rebase", { cwd: clone, stdio: "ignore" }));
    writeFileSync(join(clone, "one.txt"), "resolved\n");
    const input = makeInput({ tool_name: "apply_patch", session_id: "codex-partial" });
    const state = gatherRepoState(input);
    assert.ok(state);
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-merge");
    assert.deepEqual(plan.commit.changedPaths, ["one.txt"]);

    const result = executePlan(plan, input, state);

    assert.notEqual(result.exitCode, 0);
    assert.ok(existsSync(join(state.gitDir, "MERGE_HEAD")));
    assert.deepEqual(
      execSync("git diff --name-only --diff-filter=U", { cwd: clone, encoding: "utf-8" }).trim().split("\n"),
      ["two.txt"],
    );
    assert.match(readFileSync(join(clone, "two.txt"), "utf-8"), /^<{7}/m);
  });

  it("keeps an untouched markerless Codex conflict unmerged", () => {
    const dir = track(realpathSync(mkdtempSync(join(tmpdir(), "codex-markerless-"))));
    initRepo(dir);
    writeFileSync(join(dir, "file.txt"), "base\n");
    execSync("git add file.txt && git commit -m base", { cwd: dir, stdio: "ignore" });
    execSync("git checkout -b modified", { cwd: dir, stdio: "ignore" });
    writeFileSync(join(dir, "file.txt"), "modified\n");
    execSync("git add file.txt && git commit -m modified", { cwd: dir, stdio: "ignore" });
    execSync("git checkout main", { cwd: dir, stdio: "ignore" });
    rmSync(join(dir, "file.txt"));
    execSync("git add -A && git commit -m deleted", { cwd: dir, stdio: "ignore" });
    assert.throws(() => execSync("git merge modified", { cwd: dir, stdio: "ignore" }));
    process.chdir(dir);
    const input = makeInput({ tool_name: "apply_patch", session_id: "markerless" });
    const state = gatherRepoState(input);
    assert.ok(state);
    assert.deepEqual(state.modifiedFiles, []);
    const plan = planHook(input, state);
    assert.equal(plan.action, "commit-merge");
    assert.deepEqual(plan.commit.changedPaths, []);
    const headBefore = execSync("git rev-parse HEAD", { cwd: dir, encoding: "utf-8" }).trim();

    const result = executePlan(plan, input, state);

    assert.notEqual(result.exitCode, 0);
    assert.ok(existsSync(join(state.gitDir, "MERGE_HEAD")));
    assert.equal(execSync("git rev-parse HEAD", { cwd: dir, encoding: "utf-8" }).trim(), headBefore);
    assert.equal(execSync("git diff --name-only --diff-filter=U", { cwd: dir, encoding: "utf-8" }).trim(), "file.txt");
  });

  it("completes an already-staged merge without file_path", () => {
    const { remote, clone } = setupRepoWithRemote("staged-merge");
    track(remote);
    track(clone);
    process.chdir(clone);
    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "staged-merge-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "conflict.txt"), "remote\n");
    execSync("git add conflict.txt && git commit -m remote && git push origin main", { cwd: clone2, stdio: "ignore" });
    writeFileSync(join(clone, "conflict.txt"), "local\n");
    execSync("git add conflict.txt && git commit -m local", { cwd: clone, stdio: "ignore" });
    assert.throws(() => execSync("git pull origin main --no-rebase", { cwd: clone, stdio: "ignore" }));
    writeFileSync(join(clone, "conflict.txt"), "resolved\n");
    execSync("git add conflict.txt", { cwd: clone, stdio: "ignore" });
    const plan: HookPlan = {
      action: "commit-merge",
      commit: {
        changedPaths: [],
        subject: "auto: resolve merge conflict in resolved files",
        body: null,
      },
      sync: null,
    };
    const gitDir = execSync("git rev-parse --git-dir", { cwd: clone, encoding: "utf-8" }).trim();

    const result = executePlan(plan, makeInput({ tool_name: "apply_patch" }), makeState(clone, { gitDir, inMerge: true }));

    assert.equal(result.exitCode, 0);
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
    }

    const plan: HookPlan = {
      action: "commit-merge",
      commit: {
        changedPaths: ["conflict1.txt"],
        subject: "auto: resolve merge conflict",
        body: null,
      },
      sync: null,
    };
    const input = makeInput({ tool_input: { file_path: join(clone, "conflict1.txt") } });
    const gitDir = execSync("git rev-parse --git-dir", { cwd: clone, encoding: "utf-8" }).trim();
    const state = makeState(clone, { gitDir, hasRemote: true, inMerge: true });

    const result = executePlan(plan, input, state);
    assert.ok(result.exitCode !== 0);
  });

  it("stages and commits modified files (e.g. permission changes)", () => {
    execSync(`chmod +x "${join(dir, "seed.txt")}"`);

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        changedPaths: ["seed.txt"],
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
        changedPaths: ["root-file.txt"],
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
        changedPaths: [filePath],
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

  it("an enriched commit retains file, session, and agent provenance", () => {
    const filePath = join(dir, "provenance.txt");
    writeFileSync(filePath, "provenance\n");
    const transcriptPath = join(dir, "transcript.jsonl");
    writeFileSync(
      transcriptPath,
      jsonl({ type: "user", message: { role: "user", content: "Record provenance" } }),
    );
    const sessionId = "abcdef12-3456-7890-abcd-ef1234567890";
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        changedPaths: [filePath],
        subject: "auto: write provenance.txt",
        body: null,
      },
      sync: null,
    };
    const input = makeInput({
      tool_input: { file_path: filePath },
      transcript_path: transcriptPath,
      session_id: sessionId,
    });
    const state = makeState(dir, { relPath: "provenance.txt" });

    executePlan(plan, input, state);

    const body = execSync("git log -1 --format=%b", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(body, `File: provenance.txt\nSession: ${sessionId}\nAgent: claude`);
  });

  it("uses default subject when transcript unreadable", () => {
    const filePath = join(dir, "fallback.txt");
    writeFileSync(filePath, "fallback\n");

    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        changedPaths: [filePath],
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

  it("passes commit metadata and changed paths containing shell syntax or Git pathspec magic literally to Git", () => {
    const relativePaths = ["literal-$(touch path-was-evaluated).txt", ":(top)colon-magic.txt"];
    for (const relativePath of relativePaths) writeFileSync(join(dir, relativePath), "literal\n");
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        changedPaths: relativePaths,
        subject: "auto: keep $((1+1)) literal",
        body: null,
      },
      sync: null,
    };

    const result = executePlan(plan, makeInput(), makeState(dir));

    assert.equal(result.exitCode, 0);
    assert.equal(existsSync(join(dir, "path-was-evaluated")), false);
    const subject = execSync("git log -1 --format=%s", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(subject, "auto: keep $((1+1)) literal");
    const committed = execSync("git show --name-only --format= HEAD", { cwd: dir, encoding: "utf-8" }).trim().split("\n");
    assert.deepEqual(committed.sort(), [...relativePaths].sort());
  });

  it("does not evaluate shell expressions from commit metadata", () => {
    const filePath = join(dir, "literal-metadata.txt");
    writeFileSync(filePath, "literal\n");
    const transcriptPath = join(dir, "literal-transcript.jsonl");
    const task = "Keep $((1+1)) $(touch task-dollar-ran) `touch task-tick-ran` literal";
    writeFileSync(transcriptPath, jsonl({ type: "user", message: { role: "user", content: task } }));
    const plan: HookPlan = {
      action: "commit-and-sync",
      commit: {
        changedPaths: [filePath],
        subject: "auto: write literal-metadata.txt",
        body: null,
      },
      sync: null,
    };
    const input = makeInput({
      tool_input: { file_path: filePath },
      transcript_path: transcriptPath,
      session_id: "literal-session",
    });
    const state = makeState(dir, { relPath: "literal-metadata.txt" });

    const result = executePlan(plan, input, state);

    assert.equal(result.exitCode, 0);
    assert.equal(existsSync(join(dir, "task-dollar-ran")), false);
    assert.equal(existsSync(join(dir, "task-tick-ran")), false);
    const subject = execSync("git log -1 --format=%s", { cwd: dir, encoding: "utf-8" }).trim();
    assert.equal(subject, `auto(literal-): ${task}`);
  });
});


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

  it("pulls and pushes the current branch to its remote counterpart", () => {
    const { remote, clone } = setupRepoWithRemote("sync");
    track(remote);
    track(clone);

    process.chdir(clone);
    execSync("git checkout -b feature", { cwd: clone, stdio: "ignore" });
    execSync("git push origin feature", { cwd: clone, stdio: "ignore" });

    writeFileSync(join(clone, "new.txt"), "new\n");
    execSync("git add new.txt && git commit -m 'add new'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { currentBranch: "feature" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 0);

    const remoteFeatureLog = execSync("git log --oneline feature", { cwd: remote, encoding: "utf-8" });
    assert.match(remoteFeatureLog, /add new/);
    const remoteMainLog = execSync("git log --oneline main", { cwd: remote, encoding: "utf-8" });
    assert.doesNotMatch(remoteMainLog, /add new/);
  });

  it("does not merge another local branch", () => {
    const { remote, clone } = setupRepoWithRemote("branch-isolation");
    track(remote);
    track(clone);

    process.chdir(clone);
    execSync("git checkout -b agents", { cwd: clone, stdio: "ignore" });
    writeFileSync(join(clone, "old-agents-file.txt"), "old agent work\n");
    execSync("git add old-agents-file.txt && git commit -m 'old agents work'", { cwd: clone, stdio: "ignore" });
    execSync("git checkout -b feature main", { cwd: clone, stdio: "ignore" });

    const result = executeSync({ currentBranch: "feature" });

    assert.equal(result.exitCode, 0);
    assert.ok(!existsSync(join(clone, "old-agents-file.txt")));
  });

  it("retries push exactly once after rejection", () => {
    const { remote, clone } = setupRepoWithRemote("retry");
    track(remote);
    track(clone);

    const attempts = join(remote, "push-attempts");
    const hook = join(remote, "hooks", "pre-receive");
    writeFileSync(
      hook,
      `#!/bin/sh\ncount=0\nif [ -f "${attempts}" ]; then count=$(cat "${attempts}"); fi\ncount=$((count + 1))\nprintf '%s' "$count" > "${attempts}"\nif [ "$count" -eq 1 ]; then exit 1; fi\n`,
    );
    execSync(`chmod +x "${hook}"`);

    process.chdir(clone);
    writeFileSync(join(clone, "new.txt"), "new\n");
    execSync("git add new.txt && git commit -m 'retried commit'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { currentBranch: "main" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 0);
    assert.equal(readFileSync(attempts, "utf-8"), "2");
    const remoteLog = execSync("git log --oneline", { cwd: remote, encoding: "utf-8" });
    assert.match(remoteLog, /retried commit/);
  });

  it("retries after the branch is created remotely", () => {
    const { remote, clone } = setupRepoWithRemote("retry-new-branch");
    track(remote);
    track(clone);

    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "retry-new-branch-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    execSync("git checkout -b feature", { cwd: clone2, stdio: "ignore" });
    writeFileSync(join(clone2, "remote.txt"), "from clone2\n");
    execSync("git add remote.txt && git commit -m 'remote feature commit'", { cwd: clone2, stdio: "ignore" });

    process.chdir(clone);
    execSync("git checkout -b feature", { cwd: clone, stdio: "ignore" });
    writeFileSync(join(clone, "local.txt"), "from clone1\n");
    execSync("git add local.txt && git commit -m 'local feature commit'", { cwd: clone, stdio: "ignore" });

    const marker = join(remote, "first-push-complete");
    const hook = join(clone, ".git", "hooks", "pre-push");
    writeFileSync(
      hook,
      `#!/bin/sh\nif [ ! -f "${marker}" ]; then\n  touch "${marker}"\n  git -C "${clone2}" push origin HEAD:feature\nfi\n`,
    );
    execSync(`chmod +x "${hook}"`);

    const result = executeSync({ currentBranch: "feature" });

    assert.equal(result.exitCode, 0);
    const remoteLog = execSync("git log --oneline feature", { cwd: remote, encoding: "utf-8" });
    assert.match(remoteLog, /local feature commit/);
    assert.match(remoteLog, /remote feature commit/);
  });

  it("returns exit 2 with push-failure feedback when the retried push also fails", () => {
    const { remote, clone } = setupRepoWithRemote("push-fail");
    track(remote);
    track(clone);

    const hooksDir = join(remote, "hooks");
    mkdirSync(hooksDir, { recursive: true });
    writeFileSync(join(hooksDir, "pre-receive"), "#!/bin/sh\necho 'rejected by policy' >&2\nexit 1\n");
    execSync(`chmod +x "${join(hooksDir, "pre-receive")}"`);

    process.chdir(clone);
    writeFileSync(join(clone, "new.txt"), "new\n");
    execSync("git add new.txt && git commit -m 'add new'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { currentBranch: "main" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 2);
    assert.ok(result.stderr);
    assert.match(result.stderr, /TRUNK-SYNC FAILED/);
  });

  it("returns safe retry guidance without prescribing Git writes", () => {
    const { remote, clone } = setupRepoWithRemote("push-guidance");
    track(remote);
    track(clone);

    const hook = join(remote, "hooks", "pre-receive");
    writeFileSync(hook, "#!/bin/sh\nexit 1\n");
    execSync(`chmod +x "${hook}"`);

    process.chdir(clone);
    writeFileSync(join(clone, "new.txt"), "new\n");
    execSync("git add new.txt && git commit -m 'add new'", { cwd: clone, stdio: "ignore" });

    const result = executeSync({ currentBranch: "main" });

    assert.equal(result.exitCode, 2);
    assert.match(result.stderr ?? "", /retry after the underlying condition is corrected/i);
    assert.doesNotMatch(result.stderr ?? "", /git (pull|push)/i);
  });

  it("wraps Git output in a do-not-follow tag in push-failure feedback", () => {
    const { remote, clone } = setupRepoWithRemote("push-fence");
    track(remote);
    track(clone);

    const hook = join(remote, "hooks", "pre-receive");
    writeFileSync(hook, "#!/bin/sh\necho 'rejected by policy' >&2\nexit 1\n");
    execSync(`chmod +x "${hook}"`);

    process.chdir(clone);
    writeFileSync(join(clone, "new.txt"), "new\n");
    execSync("git add new.txt && git commit -m 'add new'", { cwd: clone, stdio: "ignore" });

    const result = executeSync({ currentBranch: "main" });

    assert.equal(result.exitCode, 2);
    assert.match(taggedGitOutput(result.stderr) ?? "", /rejected/i);
  });

  it("returns exit 2 on merge conflict during pull", () => {
    const { remote, clone } = setupRepoWithRemote("conflict");
    track(remote);
    track(clone);

    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "conflict-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "shared.txt"), "version A\n");
    execSync("git add shared.txt && git commit -m 'A' && git push origin main", {
      cwd: clone2,
      stdio: "ignore",
    });

    process.chdir(clone);
    writeFileSync(join(clone, "shared.txt"), "version B\n");
    execSync("git add shared.txt && git commit -m 'B'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { currentBranch: "main" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 2);
    assert.ok(result.stderr);
    assert.match(result.stderr, /TRUNK-SYNC CONFLICT/);
    assert.match(result.stderr, /edit the file contents/i);
    assert.doesNotMatch(result.stderr, /using Edit/);
  });

  it("wraps Git output in a do-not-follow tag in conflict feedback", () => {
    const { remote, clone } = setupRepoWithRemote("conflict-fence");
    track(remote);
    track(clone);

    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "conflict-fence-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "shared.txt"), "version A\n");
    execSync("git add shared.txt && git commit -m 'A' && git push origin main", { cwd: clone2, stdio: "ignore" });

    process.chdir(clone);
    writeFileSync(join(clone, "shared.txt"), "version B\n");
    execSync("git add shared.txt && git commit -m 'B'", { cwd: clone, stdio: "ignore" });

    const result = executeSync({ currentBranch: "main" });

    assert.equal(result.exitCode, 2);
    assert.match(taggedGitOutput(result.stderr) ?? "", /CONFLICT/);
  });

  it("returns generic remote failure when pull fails without unmerged paths", () => {
    const { remote, clone } = setupRepoWithRemote("pull-fail");
    track(remote);
    track(clone);

    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "pull-fail-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "init.txt"), "remote\n");
    execSync("git add init.txt && git commit -m remote && git push origin main", { cwd: clone2, stdio: "ignore" });

    process.chdir(clone);
    writeFileSync(join(clone, "init.txt"), "local unstaged\n");

    const result = executeSync({ currentBranch: "main" });

    assert.equal(result.exitCode, 2);
    assert.match(result.stderr ?? "", /TRUNK-SYNC REMOTE FAILURE/);
  });

  it("does not claim conflict markers for a generic pull failure", () => {
    const { remote, clone } = setupRepoWithRemote("pull-fail-guidance");
    track(remote);
    track(clone);

    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "pull-fail-guidance-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "init.txt"), "remote\n");
    execSync("git add init.txt && git commit -m remote && git push origin main", { cwd: clone2, stdio: "ignore" });

    process.chdir(clone);
    writeFileSync(join(clone, "init.txt"), "local unstaged\n");

    const result = executeSync({ currentBranch: "main" });

    assert.equal(result.exitCode, 2);
    assert.doesNotMatch(result.stderr ?? "", /conflict markers|<<<<<<<|=======|>>>>>>>/i);
  });

  it("wraps Git output in a do-not-follow tag in remote-failure feedback", () => {
    const { remote, clone } = setupRepoWithRemote("pull-fail-fence");
    track(remote);
    track(clone);

    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "pull-fail-fence-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "init.txt"), "remote\n");
    execSync("git add init.txt && git commit -m remote && git push origin main", { cwd: clone2, stdio: "ignore" });

    process.chdir(clone);
    writeFileSync(join(clone, "init.txt"), "local unstaged\n");

    const result = executeSync({ currentBranch: "main" });

    assert.equal(result.exitCode, 2);
    assert.match(taggedGitOutput(result.stderr) ?? "", /would be overwritten by merge/);
  });

  it("countermands Git's commit-or-stash hint when local changes block the pull", () => {
    const { remote, clone } = setupRepoWithRemote("pull-fail-countermand");
    track(remote);
    track(clone);

    // The file must be tracked in the shared base commit, otherwise Git reports the
    // untracked-overwrite variant instead of the commit-or-stash hint we countermand.
    writeFileSync(join(clone, "INFRA_REQUIREMENTS.md"), "base\n");
    execSync("git add INFRA_REQUIREMENTS.md && git commit -m base && git push origin main", { cwd: clone, stdio: "ignore" });

    const clone2 = track(realpathSync(mkdtempSync(join(tmpdir(), "pull-fail-countermand-clone2-"))));
    execSync(`git clone "${remote}" .`, { cwd: clone2, stdio: "ignore" });
    execSync('git config user.email "test@test.com"', { cwd: clone2 });
    execSync('git config user.name "Test"', { cwd: clone2 });
    writeFileSync(join(clone2, "INFRA_REQUIREMENTS.md"), "other agent's push\n");
    execSync("git commit -am other && git push origin main", { cwd: clone2, stdio: "ignore" });

    process.chdir(clone);
    writeFileSync(join(clone, "INFRA_REQUIREMENTS.md"), "in-flight local work\n");

    const result = executeSync({ currentBranch: "main" });
    const stderr = result.stderr ?? "";

    assert.equal(result.exitCode, 2);
    // Git's destructive hint is still shown for diagnosis, but only inside the tag.
    assert.match(taggedGitOutput(stderr) ?? "", /Please commit your changes or stash them before you merge\./);
    assert.doesNotMatch(stderr.replace(taggedGitOutput(stderr) ?? "", ""), /commit your changes or stash/);
    assert.match(stderr, /Leave the reported files as they are/i);
  });

  it("propagates an unmerged-path inspection failure", () => {
    const { remote, clone } = setupRepoWithRemote("unmerged-inspection-fail");
    track(remote);
    track(clone);
    process.chdir(clone);
    writeFileSync(join(clone, ".git", "index"), "broken index");

    assert.throws(() => executeSync({ currentBranch: "main" }), /index file|index file smaller|unknown index entry/i);
  });

  it("creates the current branch on first sync when it doesn't exist on the remote yet", () => {
    const { remote, clone } = setupRepoWithRemote("fresh-branch");
    track(remote);
    track(clone);

    process.chdir(clone);
    execSync("git checkout -b feature", { cwd: clone, stdio: "ignore" });
    writeFileSync(join(clone, "new.txt"), "new\n");
    execSync("git add new.txt && git commit -m 'add new'", { cwd: clone, stdio: "ignore" });

    const sync: SyncPlan = { currentBranch: "feature" };
    const result = executeSync(sync);

    assert.equal(result.exitCode, 0);

    const remoteLog = execSync("git log --oneline feature", { cwd: remote, encoding: "utf-8" });
    assert.match(remoteLog, /add new/);
  });

  it("fails before sync when no branch is checked out", () => {
    const { remote, clone } = setupRepoWithRemote("detached");
    track(remote);
    track(clone);

    process.chdir(clone);
    const sha = execSync("git rev-parse HEAD", { cwd: clone, encoding: "utf-8" }).trim();
    execSync(`git checkout --detach ${sha}`, { cwd: clone, stdio: "ignore" });

    const result = executeSync({ currentBranch: "" });

    assert.equal(result.exitCode, 2);
    assert.match(result.stderr ?? "", /branch must be checked out/);
  });

});

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

  it("rejects unsafe session ids without writing outside the timeclock directory", () => {
    const outsidePath = join(dir, ".trunk-sync", "escaped.json");
    const timecard: Timecard = {
      sessionId: "../escaped", hostname: "test-host",
      clockedInAt: "2026-03-27T10:00:00.000Z",
      lastActiveAt: "2026-03-27T10:05:00.000Z",
      branch: "main",
    };

    assert.throws(() => clockIn(dir, timecard), /session id/i);
    assert.equal(existsSync(outsidePath), false);
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
    const timestamp = new Date().toISOString();
    writeFileSync(join(timeclockDir, "a.json"), JSON.stringify({ sessionId: "a", hostname: "h", clockedInAt: timestamp, lastActiveAt: timestamp, branch: "main" }));
    writeFileSync(join(timeclockDir, "b.json"), JSON.stringify({ sessionId: "b", hostname: "h", clockedInAt: timestamp, lastActiveAt: timestamp, branch: "main" }));
    const timecards = readTimecards(dir);
    assert.equal(timecards.length, 2);
  });

  it("fails on malformed files", () => {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    const validTimestamp = new Date().toISOString();
    for (const malformed of [
      "not json",
      JSON.stringify({}),
      JSON.stringify({ sessionId: "", hostname: "h", clockedInAt: validTimestamp, lastActiveAt: validTimestamp, branch: "main" }),
      JSON.stringify({ sessionId: 42, hostname: "h", clockedInAt: validTimestamp, lastActiveAt: validTimestamp, branch: "main" }),
      JSON.stringify({ sessionId: "bad", hostname: "", clockedInAt: validTimestamp, lastActiveAt: validTimestamp, branch: "main" }),
      JSON.stringify({ sessionId: "bad", hostname: "h", clockedInAt: "not-a-time", lastActiveAt: validTimestamp, branch: "main" }),
      JSON.stringify({ sessionId: "bad", hostname: "h", clockedInAt: validTimestamp, lastActiveAt: "not-a-time", branch: "main" }),
      JSON.stringify({ sessionId: "bad", hostname: "h", clockedInAt: validTimestamp, lastActiveAt: validTimestamp, branch: "" }),
      JSON.stringify({ sessionId: "../unsafe", hostname: "h", clockedInAt: validTimestamp, lastActiveAt: validTimestamp, branch: "main" }),
      JSON.stringify({ sessionId: "different", hostname: "h", clockedInAt: validTimestamp, lastActiveAt: validTimestamp, branch: "main" }),
    ]) {
      writeFileSync(join(timeclockDir, "bad.json"), malformed);
      assert.throws(() => readTimecards(dir), /bad\.json/);
    }
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
    return runSessionStart(makeState(dir), sessionId, { hostname: "local-host" }).message;
  }

  it("emits no session-start context when only the starting session is present", () => {
    assert.equal(start("my-session-id"), null);
    assert.ok(existsSync(join(dir, ".trunk-sync", "timeclock", "my-session-id.json")));
  });

  it("appends the active roster when another agent is clocked in", () => {
    writeCard({ sessionId: "other-id" });
    const msg = start("my-session-id")!;
    assert.match(msg, /TRUNK-SYNC ACTIVE/);
    assert.match(msg, /other-id/);
    assert.doesNotMatch(msg, /task:/);
  });

  it("preserves unrelated staged or unstaged source and timecard changes during clock-in", () => {
    writeCard({ sessionId: "staged-card" });
    execSync("git add . && git commit -m card", { cwd: dir, stdio: "ignore" });
    writeCard({ sessionId: "staged-card", hostname: "staged-change" });
    writeFileSync(join(dir, "staged-source.txt"), "staged\n");
    execSync("git add .trunk-sync/timeclock/staged-card.json staged-source.txt", { cwd: dir });
    writeCard({ sessionId: "unstaged-card" });
    writeFileSync(join(dir, "seed.txt"), "unstaged\n");

    start("my-session-id");

    assert.equal(
      execSync("git diff-tree --no-commit-id --name-only -r HEAD", { cwd: dir, encoding: "utf-8" }).trim(),
      ".trunk-sync/timeclock/my-session-id.json",
    );
    assert.deepEqual(
      execSync("git diff --cached --name-only", { cwd: dir, encoding: "utf-8" }).trim().split("\n"),
      [".trunk-sync/timeclock/staged-card.json", "staged-source.txt"],
    );
    const status = execSync("git status --porcelain", { cwd: dir, encoding: "utf-8" });
    assert.match(status, /\?\? \.trunk-sync\/timeclock\/unstaged-card\.json/);
    assert.match(status, / M seed\.txt/);
  });

  it("does not clock in from detached HEAD", () => {
    const result = runSessionStart(makeState(dir, { currentBranch: "" }), "detached-session", { hostname: "local-host" });

    assert.equal(result.message, null);
    assert.match(result.warning ?? "", /branch must be checked out/);
    assert.ok(!existsSync(join(dir, ".trunk-sync", "timeclock", "detached-session.json")));
  });

  it("pushes the starting agent's timecard when a remote is configured", () => {
    const { remote, clone } = setupRepoWithRemote("session-start-sync");
    const previousDir = process.cwd();
    try {
      process.chdir(clone);
      const state = makeState(clone, { hasRemote: true, currentBranch: "main" });

      const { message } = runSessionStart(state, "synced-session", { hostname: "local-host" });

      assert.equal(message, null);
      execSync("git fetch origin main", { cwd: clone, stdio: "ignore" });
      const remoteCard = execSync("git show origin/main:.trunk-sync/timeclock/synced-session.json", { cwd: clone, encoding: "utf-8" });
      assert.match(remoteCard, /synced-session/);
    } finally {
      process.chdir(previousDir);
      rmSync(remote, { recursive: true, force: true });
      rmSync(clone, { recursive: true, force: true });
    }
  });

  it("creates the timeclock directory when it does not exist", () => {
    assert.equal(start("my-session-id"), null);
    assert.ok(existsSync(join(dir, ".trunk-sync", "timeclock")));
  });

  it("excludes the starting session's own timecard from the roster", () => {
    writeCard({ sessionId: "my-session-id" });
    assert.equal(start("my-session-id"), null);
  });

  it("returns null when there is no session id", () => {
    assert.equal(start(null), null);
    assert.ok(!existsSync(join(dir, ".trunk-sync", "timeclock")));
  });

  it("omits the roster when the only other card is past the reap ttl", () => {
    const reapableTime = new Date(Date.now() - 15 * 24 * 60 * 60 * 1000).toISOString();
    writeCard({ sessionId: "ghost-id", lastActiveAt: reapableTime });
    assert.equal(start("my-session-id"), null);
  });

  it("omits stale cards because timecards are presence only", () => {
    const staleTime = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
    writeCard({ sessionId: "stale-id", lastActiveAt: staleTime });
    assert.equal(start("my-session-id"), null);
  });

  it("reports local-only presence when clock-in commit fails", () => {
    const hook = join(dir, ".git", "hooks", "pre-commit");
    writeFileSync(hook, "#!/bin/sh\nexit 1\n");
    execSync(`chmod +x "${hook}"`);

    const result = runSessionStart(makeState(dir), "commit-failure", { hostname: "local-host" });

    assert.notEqual(result.warning, null);
    assert.match(result.warning ?? "", /presence is local-only/i);
    assert.match(result.warning ?? "", /lifecycle commit failed/i);
  });

  it("reports local-only presence when clock-in sync fails", () => {
    const { remote, clone } = setupRepoWithRemote("session-start-fail");
    const previousDir = process.cwd();
    try {
      process.chdir(clone);
      execSync('git remote set-url origin "/nonexistent/trunk-sync-remote.git"', { cwd: clone });

      const result = runSessionStart(
        makeState(clone, { hasRemote: true, currentBranch: "main" }),
        "sync-failure",
        { hostname: "local-host" },
      );

      assert.match(result.warning ?? "", /presence is local-only/i);
      assert.match(result.warning ?? "", /does not appear to be a git repository/i);
    } finally {
      process.chdir(previousDir);
      rmSync(remote, { recursive: true, force: true });
      rmSync(clone, { recursive: true, force: true });
    }
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

    const result = runStop(makeState(dir), "my-session");

    assert.equal(result.warning, null);
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
    const previousDir = process.cwd();
    try {
      process.chdir(clone);

      const staleTime = new Date(Date.now() - 45 * 60 * 1000).toISOString();
      const timeclockDir = join(clone, ".trunk-sync", "timeclock");
      mkdirSync(timeclockDir, { recursive: true });
      writeFileSync(join(timeclockDir, "remote-session.json"), JSON.stringify({
        sessionId: "remote-session", hostname: "h", clockedInAt: staleTime, lastActiveAt: staleTime,
        branch: "main",
      }));
      execSync("git add . && git commit -m 'add card'", { cwd: clone, stdio: "ignore" });
      writeFileSync(join(timeclockDir, "staged-card.json"), JSON.stringify({
        sessionId: "staged-card", hostname: "h", clockedInAt: staleTime, lastActiveAt: staleTime,
        branch: "main",
      }));
      writeFileSync(join(clone, "staged-source.txt"), "staged\n");
      execSync("git add .trunk-sync/timeclock/staged-card.json staged-source.txt", { cwd: clone });
      writeFileSync(join(timeclockDir, "unstaged-card.json"), JSON.stringify({
        sessionId: "unstaged-card", hostname: "h", clockedInAt: staleTime, lastActiveAt: staleTime,
        branch: "main",
      }));
      writeFileSync(join(clone, "init.txt"), "unstaged\n");

      const state = makeState(clone, { hasRemote: true, currentBranch: "main" });
      const result = runStop(state, "remote-session");

      assert.equal(result.warning, null);
      assert.equal(
        execSync("git diff-tree --no-commit-id --name-only -r HEAD", { cwd: clone, encoding: "utf-8" }).trim(),
        ".trunk-sync/timeclock/remote-session.json",
      );
      assert.deepEqual(
        execSync("git diff --cached --name-only", { cwd: clone, encoding: "utf-8" }).trim().split("\n"),
        [".trunk-sync/timeclock/staged-card.json", "staged-source.txt"],
      );
      const status = execSync("git status --porcelain", { cwd: clone, encoding: "utf-8" });
      assert.match(status, /\?\? \.trunk-sync\/timeclock\/unstaged-card\.json/);
      assert.match(status, / M init\.txt/);
      execSync("git fetch origin main", { cwd: clone, stdio: "ignore" });
      assert.throws(() => execSync("git show origin/main:.trunk-sync/timeclock/remote-session.json", { cwd: clone, stdio: "ignore" }));
    } finally {
      process.chdir(previousDir);
      rmSync(remote, { recursive: true, force: true });
      rmSync(clone, { recursive: true, force: true });
    }
  });

  it("never throws even when the post-clock-out sync fails — the stop hook always exits 0", () => {
    const { remote, clone } = setupRepoWithRemote("stop-sync-fail");
    const previousDir = process.cwd();
    try {
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

      const state = makeState(clone, { hasRemote: true, currentBranch: "main" });
      assert.doesNotThrow(() => runStop(state, "flaky-session"));

      assert.ok(!existsSync(join(timeclockDir, "flaky-session.json")));
    } finally {
      process.chdir(previousDir);
      rmSync(remote, { recursive: true, force: true });
      rmSync(clone, { recursive: true, force: true });
    }
  });

  it("warns that remote presence may be stale when clock-out sync fails", () => {
    const { remote, clone } = setupRepoWithRemote("stop-sync-warning");
    const previousDir = process.cwd();
    try {
      process.chdir(clone);
      execSync('git remote set-url origin "/nonexistent/trunk-sync-remote.git"', { cwd: clone });
      const timeclockDir = join(clone, ".trunk-sync", "timeclock");
      mkdirSync(timeclockDir, { recursive: true });
      writeFileSync(join(timeclockDir, "warning-session.json"), JSON.stringify({
        sessionId: "warning-session", hostname: "h", clockedInAt: new Date().toISOString(),
        lastActiveAt: new Date().toISOString(), branch: "main",
      }));
      execSync("git add . && git commit -m 'add card'", { cwd: clone, stdio: "ignore" });

      const result = runStop(makeState(clone, { hasRemote: true, currentBranch: "main" }), "warning-session");

      assert.match(result.warning ?? "", /remote may still show this session as active/i);
      assert.match(result.warning ?? "", /does not appear to be a git repository/i);
    } finally {
      process.chdir(previousDir);
      rmSync(remote, { recursive: true, force: true });
      rmSync(clone, { recursive: true, force: true });
    }
  });

  it("never throws when the clock-out commit fails", () => {
    const cardPath = writeCard("commit-failure", new Date().toISOString());
    const hook = join(dir, ".git", "hooks", "pre-commit");
    writeFileSync(hook, "#!/bin/sh\nexit 1\n");
    execSync(`chmod +x "${hook}"`);

    const result = runStop(makeState(dir), "commit-failure");
    assert.notEqual(result.warning, null);
    assert.match(result.warning ?? "", /lifecycle commit failed/i);
    assert.ok(!existsSync(cardPath));
  });

  it("warns that remote presence may be stale when clock-out commit fails", () => {
    writeCard("commit-warning", new Date().toISOString());
    const hook = join(dir, ".git", "hooks", "pre-commit");
    writeFileSync(hook, "#!/bin/sh\necho clock-out-commit-rejected >&2\nexit 1\n");
    execSync(`chmod +x "${hook}"`);

    const result = runStop(makeState(dir), "commit-warning");

    assert.match(result.warning ?? "", /remote may still show this session as active/i);
    assert.match(result.warning ?? "", /clock-out-commit-rejected/i);
  });

  it("returns a stale-remote warning when clock-out cannot read or remove the timecard", () => {
    const cardPath = join(dir, ".trunk-sync", "timeclock", "blocked-session.json");
    mkdirSync(join(dir, ".trunk-sync", "timeclock"), { recursive: true });
    writeFileSync(cardPath, "not-json\n");

    const result = runStop(makeState(dir), "blocked-session");

    assert.notEqual(result.warning, null);
    assert.match(result.warning ?? "", /remote may still show this session as active/i);
    assert.equal(readFileSync(cardPath, "utf-8"), "not-json\n");
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

  it("rejects unsafe session ids without removing anything outside the timeclock directory", () => {
    const outsidePath = join(dir, ".trunk-sync", "outside.json");
    writeFileSync(outsidePath, "outside\n");

    assert.throws(() => reapCards(dir, ["reap-1", "../outside"]), /session id/i);
    assert.equal(readFileSync(outsidePath, "utf-8"), "outside\n");
    assert.equal(existsSync(join(dir, ".trunk-sync", "timeclock", "reap-1.json")), true);
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
        changedPaths: [filePath],
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

  it("fails a commit that touches a malformed existing session timecard", () => {
    const cardPath = writeOwnCard();
    writeFileSync(cardPath, "not json");
    const { plan, input, state } = commitAndSyncPlan();
    assert.equal(plan.action, "commit-and-sync");
    const mergePlan: HookPlan = { action: "commit-merge", commit: plan.commit, sync: plan.sync };

    assert.throws(() => executePlan(mergePlan, input, state), /Malformed timecard: .*my-session\.json/);
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
      branch: "main",
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
        changedPaths: [join(clone, "shared.txt")],
        subject: "auto: write shared.txt",
        body: null,
      },
      sync: { currentBranch: "main" },
    };

    const input = makeInput({ session_id: "my-session", tool_input: { file_path: join(clone, "shared.txt") } });
    const state = makeState(clone, { hasRemote: true, currentBranch: "main" });
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

  it("stages no unrelated repository path when a classified card disappears before staging", () => {
    const timeclockDir = join(dir, ".trunk-sync", "timeclock");
    mkdirSync(timeclockDir, { recursive: true });
    const racePath = join(timeclockDir, "race.json");
    execSync(`mkfifo "${racePath}"`);
    const oldTimestamp = new Date(Date.now() - 20 * 24 * 60 * 60 * 1000).toISOString();
    const card = JSON.stringify({
      sessionId: "race",
      hostname: "other-host",
      clockedInAt: oldTimestamp,
      lastActiveAt: oldTimestamp,
      branch: "main",
    });
    spawn("bash", ["-c", "{ rm \"$1\"; printf '%s' \"$2\"; } > \"$1\"", "_", racePath, card], { stdio: "ignore" });
    writeFileSync(join(dir, "unrelated.txt"), "unrelated\n");
    const { plan, input, state } = commitAndSyncPlan();

    const result = executePlan(plan, input, state);

    assert.equal(result.exitCode, 0);
    assert.equal(
      execSync("git diff-tree --no-commit-id --name-only -r HEAD", { cwd: dir, encoding: "utf-8" }).trim(),
      "code.txt",
    );
    assert.match(execSync("git status --porcelain", { cwd: dir, encoding: "utf-8" }), /\?\? unrelated\.txt/);
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
