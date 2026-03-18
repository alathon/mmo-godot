import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerScriptTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_list_scripts",
    "List all scripts in the Godot project, optionally filtered by directory path.",
    {
      path: z
        .string()
        .optional()
        .describe("Optional directory path relative to res:// to filter results"),
    },
    async ({ path }) => sendCmd(godot, "list_scripts", path ? { path } : {}),
  );

  server.tool(
    "godot_create_script",
    "Create a new GDScript or C# script file in the Godot project.",
    {
      path: z
        .string()
        .describe("Path for the new script relative to res:// (e.g. 'src/player.gd')"),
      content: z
        .string()
        .optional()
        .describe("Initial script content. Defaults to a basic template if omitted."),
      node_type: z
        .string()
        .optional()
        .describe("The Godot node type this script extends (e.g. 'CharacterBody2D')"),
    },
    async (params) => sendCmd(godot, "create_script", params),
  );

  server.tool(
    "godot_edit_script",
    "Replace the entire content of an existing script file in the Godot project.",
    {
      path: z.string().describe("Path to the script file relative to res://"),
      content: z.string().describe("The new full content for the script"),
    },
    async (params) => sendCmd(godot, "edit_script", params),
  );

  server.tool(
    "godot_attach_script",
    "Attach a script to a node in the currently open scene.",
    {
      node_path: z
        .string()
        .describe("Path to the node in the scene tree (e.g. 'Player' or 'Player/Sprite2D')"),
      script_path: z
        .string()
        .describe("Path to the script file relative to res://"),
    },
    async (params) => sendCmd(godot, "attach_script", params),
  );

  server.tool(
    "godot_get_open_scripts",
    "Get a list of all scripts currently open in the Godot editor.",
    {},
    async () => sendCmd(godot, "get_open_scripts"),
  );

  server.tool(
    "godot_validate_script",
    "Validate a GDScript file for syntax errors and return any issues found.",
    {
      path: z.string().describe("Path to the script file relative to res://"),
    },
    async (params) => sendCmd(godot, "validate_script", params),
  );
}
