/**
 * SuperAgent memory-os → Copilot SDK shim (stub).
 *
 * Copilot does not natively support MCP servers. This shim wraps the
 * Python MCP server in stdio and exposes its 5 tools as Copilot SDK tools.
 *
 * Wire into your Copilot extension's tool registry:
 *
 *   import { memoryOsTools } from "./adapters/copilot/sdk-shim";
 *   copilot.registerTools(memoryOsTools);
 *
 * Revisit when Copilot ships native MCP support.
 */
import { spawn } from "node:child_process";

const MCP_BIN = process.env.SUPERAGENT_MEMORY_BIN || "superagent-memory-mcp";

interface McpResponse {
  result?: unknown;
  error?: { code: number; message: string };
}

async function callMcp(method: string, params: Record<string, unknown>): Promise<McpResponse> {
  return new Promise((resolve, reject) => {
    const proc = spawn(MCP_BIN, [], { stdio: ["pipe", "pipe", "inherit"] });
    let out = "";
    proc.stdout.on("data", (d) => (out += d.toString()));
    proc.on("close", () => {
      try {
        const lines = out.trim().split("\n").filter(Boolean);
        const last = JSON.parse(lines[lines.length - 1]);
        resolve(last);
      } catch (e) {
        reject(e);
      }
    });
    proc.stdin.write(JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: { name: method, arguments: params },
    }) + "\n");
    proc.stdin.end();
  });
}

export const memoryOsTools = [
  {
    name: "memory_recall",
    description: "Search persistent memory for entries matching a query.",
    parameters: { query: "string", limit: "number?" },
    handler: (args: Record<string, unknown>) => callMcp("memory_recall", args),
  },
  {
    name: "memory_write",
    description: "Store content in persistent memory.",
    parameters: { content: "string", kind: "string", tags: "string[]?" },
    handler: (args: Record<string, unknown>) => callMcp("memory_write", args),
  },
  {
    name: "memory_list",
    description: "List recent memory entries.",
    parameters: { kind: "string?", since: "number?", limit: "number?" },
    handler: (args: Record<string, unknown>) => callMcp("memory_list", args),
  },
  {
    name: "memory_pin",
    description: "Promote a memory entry to the workspace.",
    parameters: { entry_id: "string" },
    handler: (args: Record<string, unknown>) => callMcp("memory_pin", args),
  },
  {
    name: "memory_forget",
    description: "Soft-delete memory by id or content pattern.",
    parameters: { id_or_pattern: "string" },
    handler: (args: Record<string, unknown>) => callMcp("memory_forget", args),
  },
];
