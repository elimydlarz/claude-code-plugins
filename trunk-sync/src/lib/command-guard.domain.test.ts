import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { classifyCommand } from "./command-guard.js";

describe("Domain: command-guard", () => {
  describe("classifyCommand", () => {
    describe("when a command does not start with git", () => {
      it("then it is allowed", () => {
        assert.deepEqual(classifyCommand("pnpm test"), { exitCode: 0 });
      });
    });

    describe("when a command is git clone, diff, log, or show with optional `-C <path>`", () => {
      it("then it is allowed", () => {
        const commands = [
          "git clone source target",
          "git diff --stat",
          "git log --oneline",
          "git show HEAD",
          "git -C repo clone source target",
          "git -C repo diff --stat",
          "git -C repo log --oneline",
          "git -C repo show HEAD",
        ];

        for (const command of commands) {
          assert.deepEqual(classifyCommand(command), { exitCode: 0 }, command);
        }
      });
    });

    describe("when any other git command is received", () => {
      it("then it is rejected with file-editing guidance", () => {
        assert.deepEqual(classifyCommand("git commit -m forbidden"), {
          exitCode: 2,
          stderr: "TRUNK-SYNC: Do NOT run git commands. The trunk-sync hook handles all git operations. Your only job is to fix file contents using Edit.",
        });
      });
    });
  });
});
