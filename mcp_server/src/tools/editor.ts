import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd, sendCmdAsImage } from "./helpers.js";

export function registerEditorTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_get_editor_errors",
    "Get current errors and warnings from the Godot editor output.",
    {},
    async () => sendCmd(godot, "get_editor_errors"),
  );

  server.tool(
    "godot_get_output_log",
    "Get the contents of the Godot editor output log.",
    {
      lines: z.number().optional().describe("Maximum number of recent lines to return. Returns all if omitted."),
      clear: z.boolean().optional().describe("Whether to clear the output log after reading. Defaults to false."),
    },
    async (params) => sendCmd(godot, "get_output_log", params),
  );

  server.tool(
    "godot_get_editor_screenshot",
    "Take a screenshot of the Godot editor viewport.",
    {
      include_ui: z
        .boolean()
        .optional()
        .describe("Whether to include editor UI panels in the screenshot. Defaults to false (viewport only)."),
    },
    async (params) => sendCmdAsImage(godot, "get_editor_screenshot", params),
  );

  server.tool(
    "godot_get_game_screenshot",
    "Take a screenshot of the running game window.",
    {},
    async () => sendCmdAsImage(godot, "get_game_screenshot"),
  );

  server.tool(
    "godot_execute_editor_script",
    "Execute a GDScript snippet in the Godot editor context (EditorPlugin scope).",
    {
      script: z
        .string()
        .describe("GDScript code to execute. Has access to EditorInterface and other editor APIs."),
    },
    async (params) => sendCmd(godot, "execute_editor_script", params),
  );

  server.tool(
    "godot_clear_output",
    "Clear the Godot editor output log.",
    {},
    async () => sendCmd(godot, "clear_output"),
  );

  server.tool(
    "godot_reload_plugin",
    "Reload a specific editor plugin.",
    {
      plugin_name: z
        .string()
        .describe("Name of the plugin to reload (matches the plugin directory name in addons/)"),
    },
    async (params) => sendCmd(godot, "reload_plugin", params),
  );

  server.tool(
    "godot_reload_project",
    "Reload the entire Godot project (equivalent to reopening the project).",
    {},
    async () => sendCmd(godot, "reload_project"),
  );

  server.tool(
    "godot_get_signals",
    "Get all signals defined on a node (including inherited signals).",
    {
      node_path: z.string().describe("Path to the node in the scene tree"),
    },
    async (params) => sendCmd(godot, "get_signals", params),
  );

  server.tool(
    "godot_compare_screenshots",
    "Compare two screenshots and return a diff score (useful for visual regression testing).",
    {
      screenshot1: z.string().describe("Path or base64 data of the first screenshot"),
      screenshot2: z.string().describe("Path or base64 data of the second screenshot"),
      threshold: z
        .number()
        .optional()
        .describe("Difference threshold (0.0–1.0). Defaults to 0.01."),
    },
    async (params) => sendCmd(godot, "compare_screenshots", params),
  );
}
