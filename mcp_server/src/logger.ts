import { appendFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const moduleDir = dirname(fileURLToPath(import.meta.url));
const LOG_PATH =
  process.env.GODOT_MCP_LOG_PATH ??
  join(moduleDir, "..", "godot-mcp-debug.log");

export function log(message: string, detail?: unknown): void {
  const timestamp = new Date().toISOString();
  const suffix = detail === undefined ? "" : ` ${formatDetail(detail)}`;
  appendFileSync(
    LOG_PATH,
    `[${timestamp}] [pid:${process.pid}] ${message}${suffix}\n`,
    "utf8",
  );
}

export function getLogPath(): string {
  return LOG_PATH;
}

function formatDetail(detail: unknown): string {
  if (detail instanceof Error) {
    return JSON.stringify({
      ...detail,
      name: detail.name,
      message: detail.message,
      stack: detail.stack,
    });
  }

  try {
    return JSON.stringify(detail);
  } catch {
    return String(detail);
  }
}
