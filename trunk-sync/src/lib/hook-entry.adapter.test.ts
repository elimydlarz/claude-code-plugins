import assert from "node:assert/strict";
import { spawnSync, execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const entries = ["hook-entry.js", "pre-tool-entry.js", "session-start-entry.js", "stop-entry.js"];
let repo: string;

beforeEach(() => {
  repo = mkdtempSync(join(tmpdir(), "trunk-sync-hook-entry-"));
  execFileSync("git", ["init", "-b", "main"], { cwd: repo, stdio: "ignore" });
  execFileSync("git", ["config", "user.email", "test@example.com"], { cwd: repo });
  execFileSync("git", ["config", "user.name", "Test User"], { cwd: repo });
  writeFileSync(join(repo, "tracked.txt"), "initial\n");
  execFileSync("git", ["add", "tracked.txt"], { cwd: repo });
  execFileSync("git", ["commit", "-m", "initial"], { cwd: repo, stdio: "ignore" });
  writeFileSync(join(repo, "tracked.txt"), "dirty\n");
});

afterEach(() => {
  rmSync(repo, { recursive: true, force: true });
});

describe("Adapter: hook-entry", () => {
  describe("when PostToolUse receives empty or missing-event stdin in a dirty repository", () => {
    it("then it exits 0 without committing or staging the unrelated changes", () => {
      for (const input of ["", "{}"]) {
        const before = repoState();
        const result = runEntry("hook-entry.js", input);
        assert.equal(result.status, 0, result.stderr);
        assert.deepEqual(repoState(), before);
      }
    });
  });

  describe("when PostToolUse Edit or Write is missing a usable file_path in a dirty repository", () => {
    it("then it exits 2 with input-error feedback", () => {
      for (const toolName of ["Edit", "Write"]) {
        for (const toolInput of [{}, { file_path: "" }]) {
          const result = runEntry("hook-entry.js", JSON.stringify({ tool_name: toolName, tool_input: toolInput }));
          assert.equal(result.status, 2, `${toolName}: ${result.stderr}`);
          assert.match(result.stderr, /TRUNK-SYNC INPUT ERROR/);
        }
      }
    });

    it("and no repository state is changed", () => {
      const before = repoState();
      for (const toolName of ["Edit", "Write"]) {
        runEntry("hook-entry.js", JSON.stringify({ tool_name: toolName, tool_input: {} }));
        assert.deepEqual(repoState(), before, toolName);
      }
    });
  });

  describe("when PostToolUse Edit or Write provides a whitespace-only or NUL-containing file_path in a dirty repository", () => {
    it("then it exits 2 with input-error feedback", () => {
      for (const toolName of ["Edit", "Write"]) {
        for (const filePath of ["   ", "bad\0path"]) {
          const result = runEntry("hook-entry.js", JSON.stringify({ tool_name: toolName, tool_input: { file_path: filePath } }));
          assert.equal(result.status, 2, `${toolName}: ${result.stderr}`);
          assert.match(result.stderr, /TRUNK-SYNC INPUT ERROR/);
        }
      }
    });

    it("and no repository state is changed", () => {
      const before = repoState();
      for (const toolName of ["Edit", "Write"]) {
        for (const filePath of ["   ", "bad\0path"]) {
          runEntry("hook-entry.js", JSON.stringify({ tool_name: toolName, tool_input: { file_path: filePath } }));
          assert.deepEqual(repoState(), before, `${toolName}: ${JSON.stringify(filePath)}`);
        }
      }
    });
  });

  describe("when any hook entrypoint receives syntactically malformed or structurally invalid JSON in a dirty repository", () => {
    it("then it exits 2 with input-error feedback", () => {
      for (const input of ["not-json", "42", "[]", '{"tool_input":"invalid"}']) {
        for (const entry of entries) {
          const result = runEntry(entry, input);
          assert.equal(result.status, 2, `${entry}: ${result.stderr}`);
          assert.match(result.stderr, /TRUNK-SYNC INPUT ERROR/, entry);
        }
      }
    });

    it("and no repository state is changed", () => {
      const before = repoState();
      for (const input of ["not-json", "42", "[]", '{"tool_input":"invalid"}']) {
        for (const entry of entries) {
          runEntry(entry, input);
          assert.deepEqual(repoState(), before, `${entry}: ${input}`);
        }
      }
    });
  });

  describe("if SessionStart or Stop receives an inaccessible cwd", () => {
    it("then it exits 2 with input-error feedback", () => {
      for (const entry of ["session-start-entry.js", "stop-entry.js"]) {
        const result = runEntry(entry, JSON.stringify({
          cwd: join(repo, "missing"),
          session_id: "session-id",
        }));
        assert.equal(result.status, 2, `${entry}: ${result.stderr}`);
        assert.match(result.stderr, /TRUNK-SYNC INPUT ERROR/, entry);
      }
    });

    it("and no repository state is changed", () => {
      const before = repoState();
      for (const entry of ["session-start-entry.js", "stop-entry.js"]) {
        runEntry(entry, JSON.stringify({
          cwd: join(repo, "missing"),
          session_id: "session-id",
        }));
        assert.deepEqual(repoState(), before, entry);
      }
    });
  });

  describe("if SessionStart or Stop receives an unsafe session id", () => {
    it("then it exits 2 with input-error feedback", () => {
      for (const entry of ["session-start-entry.js", "stop-entry.js"]) {
        const result = runEntry(entry, JSON.stringify({ cwd: repo, session_id: "../escaped" }));
        assert.equal(result.status, 2, `${entry}: ${result.stderr}`);
        assert.match(result.stderr, /TRUNK-SYNC INPUT ERROR/, entry);
      }
    });

    it("and no repository state is changed", () => {
      const before = repoState();
      for (const entry of ["session-start-entry.js", "stop-entry.js"]) {
        runEntry(entry, JSON.stringify({ cwd: repo, session_id: "../escaped" }));
        assert.deepEqual(repoState(), before, entry);
      }
    });
  });
});

function runEntry(entry: string, input: string) {
  const path = fileURLToPath(new URL(entry, import.meta.url));
  return spawnSync(process.execPath, [path], { cwd: repo, input, encoding: "utf-8" });
}

function repoState() {
  return {
    head: execFileSync("git", ["rev-parse", "HEAD"], { cwd: repo, encoding: "utf-8" }),
    status: execFileSync("git", ["status", "--porcelain=v1"], { cwd: repo, encoding: "utf-8" }),
    cached: execFileSync("git", ["diff", "--cached", "--name-only"], { cwd: repo, encoding: "utf-8" }),
  };
}
