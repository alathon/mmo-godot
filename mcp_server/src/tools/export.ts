import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerExportTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_list_export_presets",
    "List all export presets defined in the project (export_presets.cfg).",
    {},
    async () => sendCmd(godot, "list_export_presets"),
  );

  server.tool(
    "godot_export_project",
    "Export the project using a named export preset.",
    {
      preset_name: z.string().describe("Name of the export preset to use"),
      path: z
        .string()
        .optional()
        .describe("Output path for the exported project. Uses the preset's configured path if omitted."),
      debug: z.boolean().optional().describe("Whether to export a debug build. Defaults to false."),
    },
    async (params) => sendCmd(godot, "export_project", params),
  );

  server.tool(
    "godot_get_export_info",
    "Get detailed configuration of a specific export preset.",
    {
      preset_name: z.string().describe("Name of the export preset to inspect"),
    },
    async (params) => sendCmd(godot, "get_export_info", params),
  );
}
