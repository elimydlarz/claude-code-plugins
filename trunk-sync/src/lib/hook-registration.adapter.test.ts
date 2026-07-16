import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { describe, it } from "node:test";

interface CommandHook {
  type: "command";
  command: string;
}

interface HookRegistration {
  matcher?: string;
  hooks: CommandHook[];
}

interface HookManifest {
  hooks: Record<"PreToolUse" | "PostToolUse" | "SessionStart" | "Stop", HookRegistration[]>;
}

const manifest = JSON.parse(readFileSync(new URL("../../hooks/hooks.json", import.meta.url), "utf-8")) as HookManifest;

describe("Adapter: hook-registration", () => {
  describe("when trunk-sync is loaded by an agent host", () => {
    it("then Bash and local_shell commands are guarded before execution", () => {
      assert.deepEqual(manifest.hooks.PreToolUse.map(({ matcher }) => matcher), ["Bash", "local_shell"]);
      assert.ok(manifest.hooks.PreToolUse.every(({ hooks }) => hooks[0].command.includes("pre-tool-entry.js")));
    });

    it("and Edit, Write, Bash, apply_patch, and local_shell changes trigger synchronization", () => {
      assert.equal(manifest.hooks.PostToolUse[0].matcher, "Edit|Write|Bash|apply_patch|local_shell");
      assert.match(manifest.hooks.PostToolUse[0].hooks[0].command, /trunk-sync\.sh$/);
    });

    it("and session start and stop trigger their lifecycle entries", () => {
      assert.match(manifest.hooks.SessionStart[0].hooks[0].command, /trunk-sync-session-start\.sh$/);
      assert.match(manifest.hooks.Stop[0].hooks[0].command, /trunk-sync-stop\.sh$/);
    });
  });
});
