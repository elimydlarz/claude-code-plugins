import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { hostname } from "node:os";
import type { Timecard } from "./hook-types.js";

export const PROGRESS_USAGE = `Usage: trunk-sync progress <session-id> --last "<step just completed>" --next "<steps still to do>"

Records your progress into your own timecard (.trunk-sync/timeclock/<session-id>.json) so other
agents — and your next session — can see where you got to and what remains. The trunk-sync hook
commits and pushes the update on the next tool use.`;

function flag(args: string[], name: string): string | null {
  const i = args.indexOf(name);
  if (i === -1 || i + 1 >= args.length) return null;
  return args[i + 1];
}

export function recordProgress(args: string[], cwd: string): string {
  const positionals: string[] = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--last" || args[i] === "--next") {
      i++;
      continue;
    }
    if (!args[i].startsWith("--")) positionals.push(args[i]);
  }
  const sessionId = positionals[0];
  if (!sessionId) throw new Error(`Missing session id.\n\n${PROGRESS_USAGE}`);

  const lastStep = flag(args, "--last");
  const remainingSteps = flag(args, "--next");

  const dir = join(cwd, ".trunk-sync", "timeclock");
  const filePath = join(dir, `${sessionId}.json`);

  let timecard: Timecard;
  try {
    timecard = JSON.parse(readFileSync(filePath, "utf-8")) as Timecard;
  } catch {
    const now = new Date().toISOString();
    timecard = {
      sessionId,
      hostname: hostname(),
      clockedInAt: now,
      lastActiveAt: now,
      branch: "detached",
      task: null,
      lastStep: null,
      remainingSteps: null,
    };
  }

  if (lastStep !== null) timecard.lastStep = lastStep;
  if (remainingSteps !== null) timecard.remainingSteps = remainingSteps;
  timecard.lastActiveAt = new Date().toISOString();

  mkdirSync(dir, { recursive: true });
  writeFileSync(filePath, JSON.stringify(timecard, null, 2) + "\n");
  return `Recorded progress for ${sessionId}.`;
}
