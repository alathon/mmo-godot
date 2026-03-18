import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerProfilingTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_get_performance_monitors",
    "Get current performance monitor values from the running game.",
    {
      monitors: z
        .array(z.string())
        .optional()
        .describe(
          "List of monitor names to retrieve (e.g. ['TIME_FPS', 'MEMORY_STATIC', 'OBJECT_COUNT']). " +
            "Returns all available monitors if omitted.",
        ),
    },
    async (params) => sendCmd(godot, "get_performance_monitors", params),
  );

  server.tool(
    "godot_get_editor_performance",
    "Get performance metrics from the Godot editor (not the running game).",
    {},
    async () => sendCmd(godot, "get_editor_performance"),
  );
}
