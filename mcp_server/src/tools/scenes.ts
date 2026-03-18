import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerSceneTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_get_scene_tree",
    "Get the node tree structure of the currently open (or specified) scene.",
    {
      scene_path: z
        .string()
        .optional()
        .describe("Path to the scene file relative to res://. Uses the currently open scene if omitted."),
    },
    async (params) => sendCmd(godot, "get_scene_tree", params),
  );

  server.tool(
    "godot_get_scene_file_content",
    "Get the raw .tscn file content of a scene.",
    {
      path: z.string().describe("Path to the scene file relative to res:// (e.g. 'src/client/Game.tscn')"),
    },
    async (params) => sendCmd(godot, "get_scene_file_content", params),
  );

  server.tool(
    "godot_create_scene",
    "Create a new scene file in the Godot project.",
    {
      path: z.string().describe("Path for the new scene relative to res:// (e.g. 'src/ui/HUD.tscn')"),
      root_type: z
        .string()
        .optional()
        .describe("Node type for the scene root (e.g. 'Node2D', 'Control'). Defaults to 'Node'."),
      root_name: z
        .string()
        .optional()
        .describe("Name for the root node. Defaults to the scene filename."),
    },
    async (params) => sendCmd(godot, "create_scene", params),
  );

  server.tool(
    "godot_open_scene",
    "Open a scene in the Godot editor.",
    {
      path: z.string().describe("Path to the scene file relative to res://"),
    },
    async (params) => sendCmd(godot, "open_scene", params),
  );

  server.tool(
    "godot_delete_scene",
    "Delete a scene file from the Godot project.",
    {
      path: z.string().describe("Path to the scene file relative to res://"),
    },
    async (params) => sendCmd(godot, "delete_scene", params),
  );

  server.tool(
    "godot_add_scene_instance",
    "Instantiate a scene as a child node in the currently open scene.",
    {
      scene_path: z.string().describe("Path to the scene to instantiate relative to res://"),
      parent_path: z.string().describe("Node path of the parent to add the instance to"),
      name: z
        .string()
        .optional()
        .describe("Name for the new instance node. Defaults to the scene name."),
    },
    async (params) => sendCmd(godot, "add_scene_instance", params),
  );

  server.tool(
    "godot_play_scene",
    "Play the current or specified scene in the Godot editor.",
    {
      scene_path: z
        .string()
        .optional()
        .describe("Path to the scene to play relative to res://. Uses the currently open scene if omitted."),
    },
    async (params) => sendCmd(godot, "play_scene", params),
  );

  server.tool(
    "godot_stop_scene",
    "Stop the currently running scene in the Godot editor.",
    {},
    async () => sendCmd(godot, "stop_scene"),
  );

  server.tool(
    "godot_save_scene",
    "Save the currently open scene, or save-as to a new path.",
    {
      path: z
        .string()
        .optional()
        .describe("Optional new path to save the scene to relative to res://. Saves in-place if omitted."),
    },
    async (params) => sendCmd(godot, "save_scene", params),
  );

  server.tool(
    "godot_get_scene_exports",
    "Get all exported variables defined in a scene's root script.",
    {
      path: z.string().describe("Path to the scene file relative to res://"),
    },
    async (params) => sendCmd(godot, "get_scene_exports", params),
  );
}
