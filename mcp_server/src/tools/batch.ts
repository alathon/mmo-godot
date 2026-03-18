import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerBatchTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_find_nodes_by_type",
    "Find all nodes of a specific type across the scene (or project).",
    {
      node_type: z.string().describe("Godot node type to search for (e.g. 'Sprite2D', 'CollisionShape2D')"),
      scene_path: z
        .string()
        .optional()
        .describe("Path to a scene file relative to res://. Uses the currently open scene if omitted."),
      recursive: z
        .boolean()
        .optional()
        .describe("Whether to search recursively through child nodes. Defaults to true."),
    },
    async (params) => sendCmd(godot, "find_nodes_by_type", params),
  );

  server.tool(
    "godot_find_signal_connections",
    "Find all signal connections on a node or for a specific signal.",
    {
      node_path: z.string().describe("Path to the node to inspect"),
      signal: z.string().optional().describe("Filter to a specific signal name. Returns all connections if omitted."),
    },
    async (params) => sendCmd(godot, "find_signal_connections", params),
  );

  server.tool(
    "godot_batch_set_property",
    "Set the same property to the same value on multiple nodes at once.",
    {
      nodes: z.array(z.string()).describe("List of node paths to update"),
      property: z.string().describe("Name of the property to set on each node"),
      value: z.any().describe("Value to set on each node"),
    },
    async (params) => sendCmd(godot, "batch_set_property", params),
  );

  server.tool(
    "godot_find_node_references",
    "Find all scene references to a specific node (nodes that reference it by path).",
    {
      node_path: z.string().describe("Path to the node to search references for"),
      scene_path: z
        .string()
        .optional()
        .describe("Scene to search in. Uses the currently open scene if omitted."),
    },
    async (params) => sendCmd(godot, "find_node_references", params),
  );

  server.tool(
    "godot_get_scene_dependencies",
    "Get all external resources and scenes that a scene file depends on.",
    {
      scene_path: z.string().describe("Path to the scene file relative to res://"),
    },
    async (params) => sendCmd(godot, "get_scene_dependencies", params),
  );

  server.tool(
    "godot_cross_scene_set_property",
    "Set a property on matching nodes across multiple scene files.",
    {
      scene_paths: z.array(z.string()).describe("List of scene file paths relative to res://"),
      node_path: z.string().describe("Node path relative to each scene root"),
      property: z.string().describe("Name of the property to set"),
      value: z.any().describe("Value to set"),
    },
    async (params) => sendCmd(godot, "cross_scene_set_property", params),
  );
}
