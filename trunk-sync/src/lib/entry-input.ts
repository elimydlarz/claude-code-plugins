export function parseInputObject(json: string): Record<string, unknown> {
  const value: unknown = JSON.parse(json);
  if (!isInputObject(value)) throw new Error("Hook input must be a JSON object.");
  return value;
}

export function isInputObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function assertSafeSessionId(sessionId: string): void {
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(sessionId)) {
    throw new Error("session id must be a safe filename component.");
  }
}

export function isUsableFilePath(filePath: string): boolean {
  return filePath.trim().length > 0 && !filePath.includes("\0");
}

export function reportInputError(error: unknown): never {
  const detail = error instanceof Error ? error.message : String(error);
  process.stderr.write(`TRUNK-SYNC INPUT ERROR: Hook input must be a valid hook JSON object. ${detail}\n`);
  process.exit(2);
}
