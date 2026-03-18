import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { GodotClient } from "./godot-client.js";
import { registerAllTools } from "./tools/index.js";

const GODOT_PORT = parseInt(process.env.GODOT_MCP_PORT ?? "6505", 10);

const godot = new GodotClient(GODOT_PORT);

const server = new McpServer({
  name: "godot-mcp-bridge",
  version: "0.1.0",
});

// ---------------------------------------------------------------------------
// Passthrough tool — forwards any command to Godot
// ---------------------------------------------------------------------------
server.tool(
  "godot_execute",
  "Execute any Godot MCP command by name. Use this for any command not covered by a dedicated tool.",
  {
    method: z.string().describe("The Godot MCP command name (e.g. 'add_node', 'get_scene_tree')"),
    params: z
      .record(z.unknown())
      .optional()
      .default({})
      .describe("Parameters to pass to the command as a JSON object"),
  },
  async ({ method, params }) => {
    try {
      const result = await godot.send(method, params as Record<string, unknown>);
      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(result, null, 2),
          },
        ],
      };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return {
        content: [{ type: "text" as const, text: `Error: ${message}` }],
        isError: true,
      };
    }
  },
);

// ---------------------------------------------------------------------------
// Register all typed tools
// ---------------------------------------------------------------------------
registerAllTools(server, godot);

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------
async function main() {
  godot.listen();

  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error(`[godot-mcp] MCP server running on stdio (Godot port ${GODOT_PORT})`);
}

main().catch((err) => {
  console.error("[godot-mcp] Fatal error:", err);
  process.exit(1);
});
