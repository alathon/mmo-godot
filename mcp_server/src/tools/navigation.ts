import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerNavigationTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_setup_navigation_region",
    "Add a NavigationRegion2D/3D node to the scene and optionally assign a mesh.",
    {
      parent_path: z.string().describe("Path to the parent node"),
      name: z.string().optional().describe("Name for the new NavigationRegion node"),
      mesh_path: z
        .string()
        .optional()
        .describe("Path to a NavigationMesh/Polygon resource relative to res://"),
    },
    async (params) => sendCmd(godot, "setup_navigation_region", params),
  );

  server.tool(
    "godot_bake_navigation_mesh",
    "Bake the navigation mesh for a NavigationRegion3D node.",
    {
      node_path: z.string().describe("Path to the NavigationRegion3D node"),
    },
    async (params) => sendCmd(godot, "bake_navigation_mesh", params),
  );

  server.tool(
    "godot_setup_navigation_agent",
    "Add a NavigationAgent2D/3D node to a parent and configure its properties.",
    {
      parent_path: z.string().describe("Path to the parent node (typically a moving character)"),
      name: z.string().optional().describe("Name for the new NavigationAgent node"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Properties to configure on the NavigationAgent (e.g. max_speed, path_desired_distance)"),
    },
    async (params) => sendCmd(godot, "setup_navigation_agent", params),
  );

  server.tool(
    "godot_set_navigation_layers",
    "Set the navigation layers bitmask for a NavigationRegion or NavigationAgent node.",
    {
      node_path: z.string().describe("Path to the NavigationRegion or NavigationAgent node"),
      layers: z.number().describe("Navigation layers bitmask"),
    },
    async (params) => sendCmd(godot, "set_navigation_layers", params),
  );

  server.tool(
    "godot_get_navigation_info",
    "Get navigation configuration info for a NavigationRegion or NavigationAgent node.",
    {
      node_path: z.string().describe("Path to the navigation node"),
    },
    async (params) => sendCmd(godot, "get_navigation_info", params),
  );
}
