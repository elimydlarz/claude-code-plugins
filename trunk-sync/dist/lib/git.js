import { execSync } from "node:child_process";
export function getGitRoot() {
    try {
        return execSync("git rev-parse --show-toplevel", { encoding: "utf-8" }).trim();
    }
    catch {
        return null;
    }
}
