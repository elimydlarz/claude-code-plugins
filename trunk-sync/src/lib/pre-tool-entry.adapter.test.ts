import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { describe, it } from "node:test";

const entryPath = new URL("./pre-tool-entry.js", import.meta.url);

describe("Adapter: command-guard", () => {
  describe("when Claude Code sends a Bash command as a string", () => {
    it("then the command is classified and its decision is returned as the hook exit", () => {
      const result = spawnSync(process.execPath, [entryPath.pathname], {
        input: JSON.stringify({ tool_name: "Bash", tool_input: { command: "git commit -m forbidden" } }),
        encoding: "utf-8",
      });

      assert.equal(result.status, 2);
    });
  });

  describe("when Codex sends a local_shell command as an array", () => {
    it("then the command is classified and its decision is returned as the hook exit", () => {
      const result = spawnSync(process.execPath, [entryPath.pathname], {
        input: JSON.stringify({ tool_name: "local_shell", tool_input: { command: ["git", "commit", "-m", "forbidden"] } }),
        encoding: "utf-8",
      });

      assert.equal(result.status, 2);
    });
  });

  describe("when the command is rejected", () => {
    it("then exit 2 and file-editing guidance are written to stderr", () => {
      const result = spawnSync(process.execPath, [entryPath.pathname], {
        input: JSON.stringify({ tool_name: "Bash", tool_input: { command: "git push" } }),
        encoding: "utf-8",
      });

      assert.equal(result.status, 2);
      assert.match(result.stderr, /Do NOT run git commands/);
      assert.match(result.stderr, /fix file contents using Edit/);
    });
  });

  describe("when the command is allowed", () => {
    it("then exit 0 is returned without feedback", () => {
      const result = spawnSync(process.execPath, [entryPath.pathname], {
        input: JSON.stringify({ tool_name: "Bash", tool_input: { command: "pnpm test" } }),
        encoding: "utf-8",
      });

      assert.equal(result.status, 0);
      assert.equal(result.stderr, "");
      assert.equal(result.stdout, "");
    });
  });
});
