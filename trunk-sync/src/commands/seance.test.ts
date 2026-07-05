import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync, mkdirSync, chmodSync, readFileSync, existsSync, realpathSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { execSync } from "node:child_process";

function gitIn(dir: string, cmd: string): string {
  return execSync(`git ${cmd}`, { cwd: dir, encoding: "utf-8" }).trim();
}

function runSeance(dir: string, args: string, extraPath?: string): string {
  const cliPath = join(process.cwd(), "dist", "cli.js");
  const pathEnv = extraPath ? `${extraPath}:${process.env.PATH}` : process.env.PATH;
  try {
    return execSync(`node "${cliPath}" seance ${args}`, {
      cwd: dir,
      encoding: "utf-8",
      env: { ...process.env, PATH: pathEnv },
    }).trim();
  } catch (e: unknown) {
    const err = e as { stderr?: string; stdout?: string };
    return (err.stderr || err.stdout || "").trim();
  }
}

// Like runSeance, but also surfaces the process's actual exit code — needed by
// tests that must assert "exits 1" literally, not just infer it from message content.
function runSeanceWithStatus(dir: string, args: string, extraPath?: string): { output: string; status: number | null } {
  const cliPath = join(process.cwd(), "dist", "cli.js");
  const pathEnv = extraPath ? `${extraPath}:${process.env.PATH}` : process.env.PATH;
  try {
    const output = execSync(`node "${cliPath}" seance ${args}`, {
      cwd: dir,
      encoding: "utf-8",
      env: { ...process.env, PATH: pathEnv },
    }).trim();
    return { output, status: 0 };
  } catch (e: unknown) {
    const err = e as { stderr?: string; stdout?: string; status?: number | null };
    return { output: (err.stderr || err.stdout || "").trim(), status: err.status ?? null };
  }
}

describe("seance", () => {
  let dir: string;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "seance-test-"));
    execSync("git init", { cwd: dir });
    gitIn(dir, 'config user.email "test@test.com"');
    gitIn(dir, 'config user.name "Test"');
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  describe("seance usage", () => {

  it("prints usage on --help without launching a CLI", () => {
    const output = runSeance(dir, "--help");
    assert.match(output, /Usage: trunk-sync seance/);
  });

  it("prints usage on -h without launching a CLI", () => {
    const output = runSeance(dir, "-h");
    assert.match(output, /Usage: trunk-sync seance/);
  });

  it("prints usage when no file:line argument is given", () => {
    const output = runSeance(dir, "");
    assert.match(output, /Usage: trunk-sync seance/);
  });

  });

  describe("seance --inspect", () => {

  it("--inspect shows session info for trunk-sync commit", () => {
    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'auto(abcd1234): add code' -m 'File: code.ts\nSession: aaaa-bbbb-cccc-dddd'");
    const sha = gitIn(dir, "rev-parse HEAD");

    const output = runSeance(dir, `${file}:1 --inspect`);
    assert.match(output, new RegExp(`Commit:\\s+${sha}`));
    assert.match(output, /Session:\s+aaaa-bbbb-cccc-dddd/);
    assert.match(output, /Subject:\s+auto\(abcd1234\): add code/);
    assert.match(output, /Line:\s+1(?!\s*\(originally)/);
  });

  it("--inspect works when blamed line has shifted", () => {
    const file = join(dir, "code.ts");
    writeFileSync(file, "const original = 1;\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'auto(abcd1234): add code' -m 'Session: shift-test-session'");

    // Add lines above so original moves from line 1 to line 3
    writeFileSync(file, "const a = 0;\nconst b = 0;\nconst original = 1;\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'add lines above'");

    const output = runSeance(dir, `${file}:3 --inspect`);
    assert.match(output, /Session:\s+shift-test-session/);
    assert.match(output, /Line:\s+3 \(originally 1\)/);
  });

  });

  describe("seance preconditions", () => {

  it("errors on uncommitted line", () => {
    const file = join(dir, "code.ts");
    writeFileSync(file, "committed\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'init'");
    writeFileSync(file, "committed\nuncommitted\n");

    const output = runSeance(dir, `${file}:2 --inspect`);
    assert.match(output, /uncommitted changes/);
  });

  it("errors on non-trunk-sync commit", () => {
    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'normal commit'");

    const output = runSeance(dir, `${file}:1 --inspect`);
    assert.match(output, /not created by trunk-sync/);
  });

  });

  describe("seance launch failures", () => {

  it("exits 1 naming the missing CLI when the resolved agent's CLI is not on PATH", () => {
    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'auto(abcd1234): add code' -m 'Session: aaaa-bbbb-cccc-dddd'");

    const gitBin = execSync("which git", { encoding: "utf-8" }).trim();
    const nodeBin = execSync("which node", { encoding: "utf-8" }).trim();
    // Minimal PATH with git and node only — no claude anywhere on it.
    const minimalPath = `${join(gitBin, "..")}:${join(nodeBin, "..")}`;
    const cliPath = join(process.cwd(), "dist", "cli.js");
    let output = "";
    let status: number | null = null;
    try {
      output = execSync(`node "${cliPath}" seance ${file}:1`, {
        cwd: dir,
        encoding: "utf-8",
        env: { PATH: minimalPath },
      }).trim();
      status = 0;
    } catch (e: unknown) {
      const err = e as { stderr?: string; stdout?: string; status?: number | null };
      output = (err.stderr || err.stdout || "").trim();
      status = err.status ?? null;
    }
    assert.match(output, /claude CLI not found/);
    assert.equal(status, 1);
  });

  it("exits 1 when creating the worktree at the blamed commit fails", () => {
    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'auto(abcd1234): add code' -m 'Session: aaaa-bbbb-cccc-dddd'");
    const sha = gitIn(dir, "rev-parse HEAD");
    const short = sha.slice(0, 8);

    // Block the exact path `git worktree add` needs with a plain file, not a directory.
    const realDir = realpathSync(dir);
    const worktreePath = join(realDir, ".claude", "worktrees", `seance-${short}`);
    mkdirSync(join(worktreePath, ".."), { recursive: true });
    writeFileSync(worktreePath, "not a worktree\n");

    const binDir = mkdtempSync(join(tmpdir(), "seance-bin-"));
    writeFileSync(join(binDir, "claude"), `#!/bin/sh\nexit 0\n`);
    chmodSync(join(binDir, "claude"), 0o755);

    const { output, status } = runSeanceWithStatus(dir, `${file}:1`, binDir);
    assert.match(output, /Failed to create worktree/);
    assert.equal(status, 1);

    rmSync(binDir, { recursive: true, force: true });
  });

  it("exits 1 when the transcript cannot be rewound to the commit timestamp", () => {
    const binDir = mkdtempSync(join(tmpdir(), "seance-bin-"));
    writeFileSync(join(binDir, "claude"), `#!/bin/sh\nexit 0\n`);
    chmodSync(join(binDir, "claude"), 0o755);

    const originalSessionId = "no-rewind-session";
    const realDir = realpathSync(dir);
    const repoSlug = realDir.replace(/[/.]/g, "-");
    const transcriptDir = join(process.env.HOME || "", ".claude", "projects", repoSlug);
    mkdirSync(transcriptDir, { recursive: true });
    const transcriptFile = join(transcriptDir, `${originalSessionId}.jsonl`);
    // Every transcript entry postdates the commit — nothing to rewind to.
    writeFileSync(transcriptFile, JSON.stringify({
      type: "user", timestamp: "2026-03-01T11:00:00.000Z", sessionId: originalSessionId, cwd: dir,
      message: { role: "user", content: "later task" },
    }) + "\n");

    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");
    const commitDate = "2026-03-01T10:00:00.000Z";
    execSync(
      `git commit -m 'auto(abcd1234): add code' -m 'Session: ${originalSessionId}'`,
      { cwd: dir, env: { ...process.env, GIT_COMMITTER_DATE: commitDate } },
    );

    const output = runSeance(dir, `${file}:1`, binDir);
    assert.match(output, /Could not rewind transcript/);

    rmSync(binDir, { recursive: true, force: true });
    rmSync(transcriptDir, { recursive: true, force: true });
  });

  });

  describe("seance --list", () => {

  it("--list shows sessions", () => {
    const file = join(dir, "code.ts");
    writeFileSync(file, "v1\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'auto(abcd1234): first' -m 'Session: sess-1111'");

    writeFileSync(file, "v2\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'auto(efgh5678): second' -m 'Session: sess-2222'");

    const output = runSeance(dir, "--list");
    assert.match(output, /sess-2222/);
    assert.match(output, /sess-1111/);
  });

  it("--list shows nothing for non-trunk-sync repos", () => {
    const file = join(dir, "code.ts");
    writeFileSync(file, "v1\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'normal commit'");

    const output = runSeance(dir, "--list");
    assert.match(output, /No trunk-sync sessions/);
  });

  });

  describe("seance default mode", () => {

  it("default mode without transcript exits with error", () => {
    const binDir = mkdtempSync(join(tmpdir(), "seance-bin-"));
    writeFileSync(
      join(binDir, "claude"),
      `#!/bin/sh\nexit 0\n`
    );
    chmodSync(join(binDir, "claude"), 0o755);

    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'auto(abcd1234): add code' -m 'File: code.ts\nSession: aaaa-bbbb-cccc-dddd'");

    const output = runSeance(dir, `${file}:1`, binDir);
    assert.match(output, /has no transcript/);

    rmSync(binDir, { recursive: true, force: true });
  });

  it("succeeds when stale worktree exists from previous seance", () => {
    const binDir = mkdtempSync(join(tmpdir(), "seance-bin-"));
    writeFileSync(
      join(binDir, "claude"),
      `#!/bin/sh\nexit 0\n`
    );
    chmodSync(join(binDir, "claude"), 0o755);

    const originalSessionId = "stale-worktree-session";
    const realDir = realpathSync(dir);
    const repoSlug = realDir.replace(/[/.]/g, "-");
    const transcriptDir = join(process.env.HOME || "", ".claude", "projects", repoSlug);
    mkdirSync(transcriptDir, { recursive: true });
    const transcriptFile = join(transcriptDir, `${originalSessionId}.jsonl`);
    const transcriptLines = [
      JSON.stringify({ type: "user", timestamp: "2026-03-01T10:00:00.000Z", sessionId: originalSessionId, cwd: dir, message: { role: "user", content: "task" } }),
    ];
    writeFileSync(transcriptFile, transcriptLines.join("\n") + "\n");

    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");
    const commitDate = "2026-03-01T10:00:01.000Z";
    execSync(
      `git commit -m 'auto(abcd1234): add code' -m 'Session: ${originalSessionId}'`,
      { cwd: dir, env: { ...process.env, GIT_COMMITTER_DATE: commitDate } }
    );
    const commitSha = gitIn(dir, "rev-parse HEAD");
    const short = commitSha.slice(0, 8);

    // Pre-create a stale worktree at the same path seance will use
    const worktreePath = join(realDir, ".claude", "worktrees", `seance-${short}`);
    execSync(`git worktree add --detach "${worktreePath}" "${commitSha}"`, { cwd: dir });
    assert.ok(existsSync(worktreePath), "stale worktree should exist before seance");

    // Seance should succeed despite the existing worktree
    const output = runSeance(dir, `${file}:1`, binDir);
    assert.match(output, /Rewound session to commit/, "seance should succeed with stale worktree");

    rmSync(binDir, { recursive: true, force: true });
    rmSync(transcriptDir, { recursive: true, force: true });
  });

  it("default mode with .transcripts/ snapshot uses snapshot for rewind", () => {
    const binDir = mkdtempSync(join(tmpdir(), "seance-bin-"));
    const logFile = join(binDir, "claude.log");
    const captureFile = join(binDir, "captured-transcript.jsonl");
    writeFileSync(
      join(binDir, "claude"),
      `#!/bin/sh
printf "cwd=%s\\n" "$(pwd)" > "${logFile}"
printf "args=" >> "${logFile}"
printf "%s " "$@" >> "${logFile}"
printf "\\n" >> "${logFile}"
RESUME_ID=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "--resume" ]; then
    RESUME_ID="$arg"
    break
  fi
  prev="$arg"
done
WORKTREE_CWD=$(pwd)
SLUG=$(echo "$WORKTREE_CWD" | sed 's|[/.]|-|g')
REWOUND_FILE="$HOME/.claude/projects/$SLUG/$RESUME_ID.jsonl"
if [ -f "$REWOUND_FILE" ]; then
  cp "$REWOUND_FILE" "${captureFile}"
fi
exit 0
`
    );
    chmodSync(join(binDir, "claude"), 0o755);

    // Create a transcript snapshot as part of the commit (simulating hook behavior)
    const originalSessionId = "snap-bbbb-cccc-dddd";
    const transcriptLines = [
      JSON.stringify({ type: "file-history-snapshot", timestamp: "2026-03-01T09:59:59.000Z", sessionId: originalSessionId, cwd: "/original/project" }),
      JSON.stringify({ type: "user", timestamp: "2026-03-01T10:00:00.000Z", sessionId: originalSessionId, cwd: "/original/project", message: { role: "user", content: "snapshot task" } }),
      JSON.stringify({ type: "assistant", timestamp: "2026-03-01T10:00:01.000Z", sessionId: originalSessionId, cwd: "/original/project", message: { role: "assistant", content: [{ type: "text", text: "working" }] } }),
    ];

    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");

    // Commit with code, then amend to include snapshot (like the hook does)
    const commitDate = "2026-03-01T10:00:01.500Z";
    execSync(
      `git commit -m 'auto(snap1234): add code' -m 'File: code.ts\nSession: ${originalSessionId}'`,
      { cwd: dir, env: { ...process.env, GIT_COMMITTER_DATE: commitDate } }
    );

    // Add snapshot to .transcripts/ and amend
    const snapshotDir = join(dir, ".transcripts");
    mkdirSync(snapshotDir, { recursive: true });
    writeFileSync(join(snapshotDir, "snap1234-1234567890.jsonl"), transcriptLines.join("\n") + "\n");
    execSync("git add .transcripts && git commit --amend --no-edit", {
      cwd: dir,
      env: { ...process.env, GIT_COMMITTER_DATE: commitDate },
    });

    // A rival transcript at the derived path, with a different line count, so the
    // assertion below can tell which source actually won if the snapshot were ignored.
    const realDir = realpathSync(dir);
    const repoSlug = realDir.replace(/[/.]/g, "-");
    const derivedDir = join(process.env.HOME || "", ".claude", "projects", repoSlug);
    mkdirSync(derivedDir, { recursive: true });
    writeFileSync(
      join(derivedDir, `${originalSessionId}.jsonl`),
      JSON.stringify({ type: "user", timestamp: "2026-03-01T10:00:00.000Z", sessionId: originalSessionId, cwd: "/derived/rival", message: { role: "user", content: "rival task" } }) + "\n",
    );

    const output = runSeance(dir, `${file}:1`, binDir);

    // Should rewind using the snapshot (no Transcript: field needed)
    assert.match(output, /Rewound session to commit/);
    assert.match(output, new RegExp(`Forking session ${originalSessionId}`));

    // Verify the rewound transcript was created from the snapshot, not the rival derived-path transcript
    assert.ok(existsSync(captureFile), "mock claude should have captured the rewound transcript");
    const capturedLines = readFileSync(captureFile, "utf-8").split("\n").filter(Boolean);
    assert.equal(capturedLines.length, 3, "should have all 3 snapshot lines (timestamps <= commit time), not the rival's 1");

    rmSync(derivedDir, { recursive: true, force: true });

    // seance-read-only: claude is launched with restrictive flags
    const loggedArgs = readFileSync(logFile, "utf-8");
    assert.match(loggedArgs, /--allowedTools Read,Bash\(git log:\*\),Bash\(git show:\*\),Bash\(git diff:\*\)/);
    assert.match(loggedArgs, /--permission-mode plan/);
    assert.match(loggedArgs, /--append-system-prompt/);

    // seance-context-purity: system prompt forbids tool calls in the first response
    assert.match(loggedArgs, /SEANCE MODE/);
    assert.match(loggedArgs, /MUST NOT edit, write, or create any files/);
    assert.match(loggedArgs, /first response must be a direct explanation with ZERO tool calls/);

    rmSync(binDir, { recursive: true, force: true });
  });

  it("uses the transcript at TranscriptPath from the commit body when there is no snapshot", () => {
    const binDir = mkdtempSync(join(tmpdir(), "seance-bin-"));
    writeFileSync(join(binDir, "claude"), `#!/bin/sh\nexit 0\n`);
    chmodSync(join(binDir, "claude"), 0o755);

    const originalSessionId = "transcript-path-session";
    // Deliberately NOT at the derived path — only reachable via the commit body's TranscriptPath
    const customTranscriptDir = mkdtempSync(join(tmpdir(), "seance-custom-transcript-"));
    const transcriptFile = join(customTranscriptDir, `${originalSessionId}.jsonl`);
    writeFileSync(transcriptFile, JSON.stringify({
      type: "user", timestamp: "2026-03-01T10:00:00.000Z", sessionId: originalSessionId, cwd: "/original/project",
      message: { role: "user", content: "task" },
    }) + "\n");

    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");
    const commitDate = "2026-03-01T10:00:01.000Z";
    execSync(
      `git commit -m 'auto(abcd1234): add code' -m 'Session: ${originalSessionId}\nTranscriptPath: ${transcriptFile}'`,
      { cwd: dir, env: { ...process.env, GIT_COMMITTER_DATE: commitDate } },
    );

    const output = runSeance(dir, `${file}:1`, binDir);
    assert.match(output, /Rewound session to commit/);

    rmSync(binDir, { recursive: true, force: true });
    rmSync(customTranscriptDir, { recursive: true, force: true });
  });

  it("prompt uses original line number from blamed commit, not current line", () => {
    const binDir = mkdtempSync(join(tmpdir(), "seance-bin-"));
    const logFile = join(binDir, "claude.log");
    writeFileSync(
      join(binDir, "claude"),
      `#!/bin/sh
printf "args=" > "${logFile}"
printf "%s " "$@" >> "${logFile}"
printf "\\n" >> "${logFile}"
exit 0
`
    );
    chmodSync(join(binDir, "claude"), 0o755);

    const originalSessionId = "orig-line-test-session";
    const realDir = realpathSync(dir);
    const repoSlug = realDir.replace(/[/.]/g, "-");
    const transcriptDir = join(process.env.HOME || "", ".claude", "projects", repoSlug);
    mkdirSync(transcriptDir, { recursive: true });
    const transcriptFile = join(transcriptDir, `${originalSessionId}.jsonl`);

    // Commit 1: 'target line' is at line 1
    const file = join(dir, "code.ts");
    const commitDate = "2026-03-01T10:00:01.000Z";
    writeFileSync(file, "const target = true;\n");
    gitIn(dir, "add code.ts");
    execSync(
      `git commit -m 'auto(abcd1234): add code' -m 'Session: ${originalSessionId}'`,
      { cwd: dir, env: { ...process.env, GIT_COMMITTER_DATE: commitDate } }
    );

    // Commit 2: add lines above, pushing 'target' from line 1 → line 4
    writeFileSync(file, "import a from 'a';\nimport b from 'b';\nimport c from 'c';\nconst target = true;\n");
    gitIn(dir, "add code.ts");
    gitIn(dir, "commit -m 'add imports'");

    // Write a transcript that covers the first commit's timestamp
    const transcriptLines = [
      JSON.stringify({ type: "user", timestamp: "2026-03-01T10:00:00.000Z", sessionId: originalSessionId, cwd: dir, message: { role: "user", content: "task" } }),
      JSON.stringify({ type: "assistant", timestamp: "2026-03-01T10:00:01.000Z", sessionId: originalSessionId, cwd: dir, message: { role: "assistant", content: [{ type: "text", text: "done" }] } }),
    ];
    writeFileSync(transcriptFile, transcriptLines.join("\n") + "\n");

    // Seance line 4 in current file — should blame back to commit 1 where it was line 1
    const output = runSeance(dir, `${file}:4`, binDir);
    assert.match(output, /Rewound session to commit/);

    // The prompt passed to claude should reference line 1, not line 4
    const log = readFileSync(logFile, "utf-8");
    assert.match(log, /code\.ts:1/, "prompt should reference original line 1, not current line 4");
    assert.ok(!log.includes("code.ts:4"), "prompt should NOT reference current line 4");
    assert.match(log, /const target = true;/, "prompt should include the blamed line's code content");

    rmSync(binDir, { recursive: true, force: true });
    rmSync(transcriptDir, { recursive: true, force: true });
  });

  });

  describe("seance default mode (Claude commit)", () => {

  it("default mode with transcript rewinds session to commit point", () => {
    const binDir = mkdtempSync(join(tmpdir(), "seance-bin-"));
    const logFile = join(binDir, "claude.log");
    // Mock claude binary that captures the rewound transcript before exiting
    const captureFile = join(binDir, "captured-transcript.jsonl");
    writeFileSync(
      join(binDir, "claude"),
      `#!/bin/sh
printf "cwd=%s\\n" "$(pwd)" > "${logFile}"
printf "args=" >> "${logFile}"
printf "%s " "$@" >> "${logFile}"
printf "\\n" >> "${logFile}"
# Capture the rewound transcript content so we can verify it
RESUME_ID=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "--resume" ]; then
    RESUME_ID="$arg"
    break
  fi
  prev="$arg"
done
# Find the rewound file by looking in the project dir for the worktree
WORKTREE_CWD=$(pwd)
SLUG=$(echo "$WORKTREE_CWD" | sed 's|[/.]|-|g')
REWOUND_FILE="$HOME/.claude/projects/$SLUG/$RESUME_ID.jsonl"
if [ -f "$REWOUND_FILE" ]; then
  cp "$REWOUND_FILE" "${captureFile}"
fi
exit 0
`
    );
    chmodSync(join(binDir, "claude"), 0o755);

    // Create a fake transcript at the derived path seance will look for
    const originalSessionId = "aaaa-bbbb-cccc-dddd";
    const realDir = realpathSync(dir);
    const repoSlug = realDir.replace(/[/.]/g, "-");
    const transcriptDir = join(process.env.HOME || "", ".claude", "projects", repoSlug);
    mkdirSync(transcriptDir, { recursive: true });
    const transcriptFile = join(transcriptDir, `${originalSessionId}.jsonl`);
    const transcriptLines = [
      JSON.stringify({ type: "file-history-snapshot", timestamp: "2026-03-01T09:59:59.000Z", sessionId: originalSessionId, cwd: "/original/project" }),
      JSON.stringify({ type: "user", timestamp: "2026-03-01T10:00:00.000Z", sessionId: originalSessionId, cwd: "/original/project", message: { role: "user", content: "first task" } }),
      JSON.stringify({ type: "assistant", timestamp: "2026-03-01T10:00:01.000Z", sessionId: originalSessionId, cwd: "/original/project", message: { role: "assistant", content: [{ type: "text", text: "working on it" }] } }),
      JSON.stringify({ type: "assistant", timestamp: "2026-03-01T10:00:02.000Z", sessionId: originalSessionId, cwd: "/original/project", message: { role: "assistant", content: [{ type: "tool_use" }] } }),
      JSON.stringify({ type: "user", timestamp: "2026-03-01T10:00:03.000Z", sessionId: originalSessionId, cwd: "/original/project", message: { role: "user", content: "second task" } }),
      JSON.stringify({ type: "assistant", timestamp: "2026-03-01T10:00:04.000Z", sessionId: originalSessionId, cwd: "/original/project", message: { role: "assistant", content: [{ type: "text", text: "later work" }] } }),
    ];
    writeFileSync(transcriptFile, transcriptLines.join("\n") + "\n");

    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");

    // Use GIT_COMMITTER_DATE to set the commit timestamp to 10:00:02.500
    // (between lines 3 and 4 of the transcript)
    const commitDate = "2026-03-01T10:00:02.500Z";
    execSync(
      `git commit -m 'auto(abcd1234): add code' -m 'File: code.ts\nSession: ${originalSessionId}'`,
      { cwd: dir, env: { ...process.env, GIT_COMMITTER_DATE: commitDate } }
    );
    const commitSha = gitIn(dir, "rev-parse HEAD");
    const short = commitSha.slice(0, 8);

    const output = runSeance(dir, `${file}:1`, binDir);

    // Verify rewind happened
    assert.match(output, /Rewound session to commit/);
    assert.match(output, /Forking session aaaa-bbbb-cccc-dddd/);

    // Verify claude was called with a NEW session ID (not the original)
    const log = readFileSync(logFile, "utf-8");
    assert.ok(!log.includes(`--resume ${originalSessionId}`), "should resume from rewound session, not original");
    assert.match(log, /--resume/);

    // Extract the new session ID from the claude args
    const resumeMatch = log.match(/--resume ([^\s]+)/);
    assert.ok(resumeMatch, "should have --resume arg");
    const newSessionId = resumeMatch![1];
    assert.notEqual(newSessionId, originalSessionId, "new session ID should differ from original");

    // Verify the rewound transcript has correct content
    assert.ok(existsSync(captureFile), "mock claude should have captured the rewound transcript");
    const capturedLines = readFileSync(captureFile, "utf-8").split("\n").filter(Boolean);
    assert.equal(capturedLines.length, 4, "should have 4 lines (timestamps <= 10:00:02.500)");

    // Verify sessionId and cwd were rewritten in the rewound transcript
    // Use realpathSync because git rev-parse --show-toplevel resolves symlinks (e.g. /var → /private/var on macOS)
    const worktreePath = join(realpathSync(dir), ".claude", "worktrees", `seance-${short}`);
    for (const line of capturedLines) {
      const obj = JSON.parse(line);
      if (obj.sessionId) {
        assert.equal(obj.sessionId, newSessionId, "sessionId should be rewritten to new ID");
      }
      if (obj.cwd) {
        assert.equal(obj.cwd, worktreePath, "cwd should be rewritten to worktree path");
      }
    }

    // Verify worktree was cleaned up
    const worktrees = gitIn(dir, "worktree list");
    assert.ok(!worktrees.includes(`seance-${short}`), "worktree should be removed after claude exits");

    // Verify rewound transcript was cleaned up (it's in the project dir, not transcriptDir)
    const slug = worktreePath.replace(/[/.]/g, "-");
    const projectDir = join(process.env.HOME || "", ".claude", "projects", slug);
    const rewoundFile = join(projectDir, `${newSessionId}.jsonl`);
    assert.ok(!existsSync(rewoundFile), "rewound transcript should be cleaned up after claude exits");

    // Original transcript should be untouched
    const originalLines = readFileSync(transcriptFile, "utf-8").split("\n").filter(Boolean);
    assert.equal(originalLines.length, 6, "original transcript should be untouched");

    rmSync(binDir, { recursive: true, force: true });
    rmSync(transcriptDir, { recursive: true, force: true });
    // Clean up project dir if empty
    try { rmSync(projectDir, { recursive: true, force: true }); } catch { /* ok */ }
  });

  });

  describe("seance default mode (Codex commit)", () => {

  it("default mode resumes a Codex commit by writing a rewritten rollout and spawning codex exec resume", () => {
    const fakeHome = realpathSync(mkdtempSync(join(tmpdir(), "seance-codex-home-")));
    const binDir = mkdtempSync(join(tmpdir(), "seance-codex-bin-"));
    const logFile = join(binDir, "codex.log");
    const captureFile = join(binDir, "captured-rollout.jsonl");

    // Fake `codex` binary: log args + cwd, find the rewritten rollout under
    // $HOME/.codex/sessions/ matching the resume UUID, copy it to captureFile.
    writeFileSync(
      join(binDir, "codex"),
      `#!/bin/sh
printf "HOME=%s\\n" "$HOME" > "${logFile}"
printf "cwd=%s\\n" "$(pwd)" >> "${logFile}"
printf "args=" >> "${logFile}"
printf "%s " "$@" >> "${logFile}"
printf "\\n" >> "${logFile}"
RESUME_ID=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "resume" ]; then
    RESUME_ID="$arg"
    break
  fi
  prev="$arg"
done
printf "RESUME_ID=%s\\n" "$RESUME_ID" >> "${logFile}"
printf "find_results=\\n" >> "${logFile}"
find "$HOME/.codex/sessions" -type f 2>/dev/null >> "${logFile}"
FOUND=$(find "$HOME/.codex/sessions" -name "*$RESUME_ID.jsonl" 2>/dev/null | head -1)
if [ -n "$FOUND" ]; then
  cp "$FOUND" "${captureFile}"
fi
exit 0
`,
    );
    chmodSync(join(binDir, "codex"), 0o755);
    // Also stub `claude` (commandExists check uses `command -v` — codex path won't need it,
    // but other code paths in seance call commandExists("claude") only on Claude branch).

    const originalUuid = "019c27eb-440a-7c90-b1ba-6c52f3be3b04";
    const rolloutDir = join(fakeHome, ".codex", "sessions", "2026", "03", "01");
    mkdirSync(rolloutDir, { recursive: true });
    const rolloutPath = join(rolloutDir, `rollout-2026-03-01T10-00-00-${originalUuid}.jsonl`);
    const rolloutLines = [
      JSON.stringify({
        timestamp: "2026-03-01T09:59:59.000Z",
        type: "session_meta",
        payload: { id: originalUuid, cwd: "/original/project", originator: "Codex" },
      }),
      JSON.stringify({
        timestamp: "2026-03-01T10:00:00.000Z",
        type: "event_msg",
        payload: { kind: "user_message", text: "task" },
      }),
      JSON.stringify({
        timestamp: "2026-03-01T10:00:02.000Z",
        type: "event_msg",
        payload: { kind: "assistant", text: "working" },
      }),
      JSON.stringify({
        timestamp: "2026-03-01T10:00:05.000Z",
        type: "event_msg",
        payload: { kind: "assistant", text: "later" },
      }),
    ];
    writeFileSync(rolloutPath, rolloutLines.join("\n") + "\n");

    const file = join(dir, "code.ts");
    writeFileSync(file, "const x = 1;\n");
    gitIn(dir, "add code.ts");
    const commitDate = "2026-03-01T10:00:02.500Z";
    execSync(
      `git commit -m 'auto(codx1234): add code' -m 'Session: ${originalUuid}\nAgent: codex\nTranscriptPath: ${rolloutPath}'`,
      { cwd: dir, env: { ...process.env, GIT_COMMITTER_DATE: commitDate } },
    );
    const commitSha = gitIn(dir, "rev-parse HEAD");
    const short = commitSha.slice(0, 8);

    // Run seance with HOME pointed at the fake home so the rewritten rollout is isolated.
    const cliPath = join(process.cwd(), "dist", "cli.js");
    const env = { ...process.env, HOME: fakeHome, PATH: `${binDir}:${process.env.PATH}` };
    let output = "";
    try {
      output = execSync(`node "${cliPath}" seance ${file}:1`, {
        cwd: dir,
        encoding: "utf-8",
        env,
      }).trim();
    } catch (e: unknown) {
      const err = e as { stderr?: string; stdout?: string };
      output = (err.stderr || err.stdout || "").trim();
    }

    assert.match(output, /Rewound session to commit/);

    const log = readFileSync(logFile, "utf-8");
    assert.match(log, /\bexec\b/, "codex should be invoked via `exec`");
    assert.match(log, /\bresume\b/);
    assert.match(log, /--sandbox read-only/);
    assert.match(log, /--ask-for-approval never/);
    assert.match(log, /--skip-git-repo-check/);
    assert.match(log, /-C \S*seance-/);
    const uuidMatch = log.match(/resume ([0-9a-f-]{36})/);
    assert.ok(uuidMatch, "resume should be followed by a UUID");
    const newUuid = uuidMatch![1];
    assert.notEqual(newUuid, originalUuid, "new UUID should differ from original");

    assert.ok(existsSync(captureFile), "fake codex should have captured the rewritten rollout");
    const capturedLines = readFileSync(captureFile, "utf-8").split("\n").filter(Boolean);
    assert.equal(capturedLines.length, 3, "should drop the line after the commit timestamp");
    const sessionMeta = JSON.parse(capturedLines[0]);
    assert.equal(sessionMeta.payload.id, newUuid);
    const worktreePath = join(realpathSync(dir), ".claude", "worktrees", `seance-${short}`);
    assert.equal(sessionMeta.payload.cwd, worktreePath);

    // Original rollout untouched.
    assert.equal(
      readFileSync(rolloutPath, "utf-8").split("\n").filter(Boolean).length,
      4,
    );

    // Worktree cleaned up.
    const worktrees = gitIn(dir, "worktree list");
    assert.ok(!worktrees.includes(`seance-${short}`));

    // Rewritten rollout cleaned up.
    const rewrittenPath = join(fakeHome, ".codex", "sessions", "2026", "03", "01");
    const remaining = existsSync(rewrittenPath)
      ? execSync(`ls "${rewrittenPath}"`, { encoding: "utf-8" }).trim().split("\n").filter(Boolean)
      : [];
    assert.ok(
      !remaining.some((f) => f.includes(newUuid)),
      "rewritten rollout should be deleted after codex exits",
    );

    rmSync(binDir, { recursive: true, force: true });
    rmSync(fakeHome, { recursive: true, force: true });
  });

  });

});
