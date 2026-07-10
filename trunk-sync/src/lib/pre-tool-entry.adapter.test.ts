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
});
