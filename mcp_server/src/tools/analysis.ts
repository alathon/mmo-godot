import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerAnalysisTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_find_unused_resources",
    "Find resource files in the project that are not referenced by any scene or script.",
    {
      path: z
        .string()
        .optional()
        .describe("Directory to search in relative to res://. Defaults to entire project."),
    },
    async (params) => sendCmd(godot, "find_unused_resources", params),
  );

  server.tool(
    "godot_analyze_signal_flow",
    "Analyze and map all signal connections in a scene to show the event flow.",
    {
      scene_path: z
        .string()
        .optional()
        .describe("Path to the scene file relative to res://. Uses the currently open scene if omitted."),
    },
    async (params) => sendCmd(godot, "analyze_signal_flow", params),
  );

  server.tool(
    "godot_analyze_scene_complexity",
    "Analyze a scene's complexity: node count, draw calls, physics bodies, scripts, etc.",
    {
      scene_path: z.string().describe("Path to the scene file relative to res://"),
    },
    async (params) => sendCmd(godot, "analyze_scene_complexity", params),
  );

  server.tool(
    "godot_find_script_references",
    "Find all files in the project that reference a specific script.",
    {
      script_path: z.string().describe("Path to the script file relative to res://"),
    },
    async (params) => sendCmd(godot, "find_script_references", params),
  );

  server.tool(
    "godot_detect_circular_dependencies",
    "Detect circular dependencies between scripts and scenes in the project.",
    {
      path: z
        .string()
        .optional()
        .describe("Directory to analyze relative to res://. Defaults to entire project."),
    },
    async (params) => sendCmd(godot, "detect_circular_dependencies", params),
  );

  server.tool(
    "godot_get_project_statistics",
    "Get overall project statistics: scene count, script count, resource types, total size, etc.",
    {},
    async () => sendCmd(godot, "get_project_statistics"),
  );
}
