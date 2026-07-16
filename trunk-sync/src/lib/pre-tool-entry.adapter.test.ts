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
    it("then exit 2 and guidance that inspection is allowed and trunk-sync owns git writes are written to stderr", () => {
      const result = spawnSync(process.execPath, [entryPath.pathname], {
        input: JSON.stringify({ tool_name: "Bash", tool_input: { command: "git push" } }),
        encoding: "utf-8",
      });

      assert.equal(result.status, 2);
      assert.match(result.stderr, /Do NOT run write-side git commands/);
      assert.match(result.stderr, /Read-only git inspection is allowed/);
      assert.match(result.stderr, /Trunk-sync handles git writes/);
    });

    it("and shell command-string wrappers, eval, command-position substitutions, and command-position parameter expansions cannot bypass the guard", () => {
      for (const command of [
        "/bin/sh -c 'git push'",
        "bash -lc 'git push'",
        "/bin/sh -xec 'git push'",
        "/bin/sh -c 'g\\it push'",
        "eval 'git push'",
        "eval 'g\\it push'",
        "command -p git push",
        "time git push",
        "! git push",
        "G=it; g$G push",
        "FOO='x y' git push",
        "$(printf git) push",
        "G=git; $G push",
        "G=git; \"$G\" push",
        "G=git; \"${G}\" push",
        "G=/usr/bin; \"$G\"/git push",
        "G=/usr/bin; \"${G}\"/git push",
        "${GIT:-git} push",
        "git status \"$(eval 'git push')\"",
      ]) {
        const result = spawnSync(process.execPath, [entryPath.pathname], {
          input: JSON.stringify({ tool_name: "Bash", tool_input: { command } }),
          encoding: "utf-8",
        });

        assert.equal(result.status, 2, `${command}\n${result.stderr}`);
        assert.match(result.stderr, /standalone Git inspection/, command);
      }
    });
  });

  describe("when the command is allowed", () => {
    it("then exit 0 is returned without feedback", () => {
      for (const command of ["pnpm test", "time pnpm test", "! false", "printf 'g$G push'", "printf value > git"]) {
        const result = spawnSync(process.execPath, [entryPath.pathname], {
          input: JSON.stringify({ tool_name: "Bash", tool_input: { command } }),
          encoding: "utf-8",
        });

        assert.equal(result.status, 0, command);
        assert.equal(result.stderr, "", command);
        assert.equal(result.stdout, "", command);
      }
    });
  });
});
