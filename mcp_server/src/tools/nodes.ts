import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerNodeTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_add_node",
    "Add a new node as a child of an existing node in the currently open scene.",
    {
      parent_path: z.string().describe("Node path of the parent (e.g. 'Player' or '.' for root)"),
      node_type: z.string().describe("Godot node type to create (e.g. 'Sprite2D', 'CollisionShape2D')"),
      name: z.string().optional().describe("Name for the new node. Defaults to the node type name."),
    },
    async (params) => sendCmd(godot, "add_node", params),
  );

  server.tool(
    "godot_delete_node",
    "Delete a node from the currently open scene.",
    {
      node_path: z.string().describe("Path to the node in the scene tree"),
    },
    async (params) => sendCmd(godot, "delete_node", params),
  );

  server.tool(
    "godot_duplicate_node",
    "Duplicate a node in the currently open scene.",
    {
      node_path: z.string().describe("Path to the node to duplicate"),
      new_name: z.string().optional().describe("Name for the duplicated node"),
      parent_path: z.string().optional().describe("Parent path for the duplicate. Defaults to same parent."),
    },
    async (params) => sendCmd(godot, "duplicate_node", params),
  );

  server.tool(
    "godot_move_node",
    "Move a node to a new parent in the currently open scene.",
    {
      node_path: z.string().describe("Path to the node to move"),
      new_parent_path: z.string().describe("Path of the new parent node"),
    },
    async (params) => sendCmd(godot, "move_node", params),
  );

  server.tool(
    "godot_update_property",
    "Update a property on a node in the currently open scene.",
    {
      node_path: z.string().describe("Path to the node in the scene tree"),
      property: z.string().describe("Name of the property to set (e.g. 'position', 'visible', 'texture')"),
      value: z
        .any()
        .describe(
          "The new value. Use native JSON types for simple values (bool, number, string). " +
            "For Godot types use string representation (e.g. 'Vector2(10, 20)', 'Color(1,0,0,1)').",
        ),
    },
    async (params) => sendCmd(godot, "update_property", params),
  );

  server.tool(
    "godot_get_node_properties",
    "Get all properties and their current values for a node in the scene.",
    {
      node_path: z.string().describe("Path to the node in the scene tree"),
    },
    async (params) => sendCmd(godot, "get_node_properties", params),
  );

  server.tool(
    "godot_add_resource",
    "Create and assign a new resource to a node property.",
    {
      node_path: z.string().describe("Path to the node in the scene tree"),
      property: z.string().describe("Name of the property to assign the resource to"),
      resource_type: z.string().describe("Type of resource to create (e.g. 'PhysicsMaterial', 'SpriteFrames')"),
    },
    async (params) => sendCmd(godot, "add_resource", params),
  );

  server.tool(
    "godot_set_anchor_preset",
    "Set an anchor preset on a Control node (e.g. full rect, top-left, center).",
    {
      node_path: z.string().describe("Path to the Control node"),
      preset: z
        .number()
        .describe(
          "Anchor preset integer (matches Godot's PRESET_* constants: 0=TOP_LEFT, 1=TOP_RIGHT, 2=BOTTOM_LEFT, 3=BOTTOM_RIGHT, 4=CENTER_LEFT, 5=CENTER_TOP, 6=CENTER_RIGHT, 7=CENTER_BOTTOM, 8=CENTER, 9=LEFT_WIDE, 10=TOP_WIDE, 11=RIGHT_WIDE, 12=BOTTOM_WIDE, 13=VCENTER_WIDE, 14=HCENTER_WIDE, 15=FULL_RECT)",
        ),
    },
    async (params) => sendCmd(godot, "set_anchor_preset", params),
  );

  server.tool(
    "godot_rename_node",
    "Rename a node in the currently open scene.",
    {
      node_path: z.string().describe("Path to the node to rename"),
      new_name: z.string().describe("New name for the node"),
    },
    async (params) => sendCmd(godot, "rename_node", params),
  );

  server.tool(
    "godot_connect_signal",
    "Connect a signal from one node to a method on another node.",
    {
      source_path: z.string().describe("Path to the node emitting the signal"),
      signal: z.string().describe("Name of the signal to connect"),
      target_path: z.string().describe("Path to the node receiving the signal"),
      method: z.string().describe("Name of the method to call on the target node"),
      flags: z.number().optional().describe("Optional connection flags (e.g. CONNECT_ONE_SHOT = 4)"),
    },
    async (params) => sendCmd(godot, "connect_signal", params),
  );

  server.tool(
    "godot_disconnect_signal",
    "Disconnect a signal connection between two nodes.",
    {
      source_path: z.string().describe("Path to the node emitting the signal"),
      signal: z.string().describe("Name of the signal"),
      target_path: z.string().describe("Path to the target node"),
      method: z.string().describe("Name of the connected method"),
    },
    async (params) => sendCmd(godot, "disconnect_signal", params),
  );

  server.tool(
    "godot_get_node_groups",
    "Get all groups that a node belongs to.",
    {
      node_path: z.string().describe("Path to the node in the scene tree"),
    },
    async (params) => sendCmd(godot, "get_node_groups", params),
  );

  server.tool(
    "godot_set_node_groups",
    "Set the groups a node belongs to (replaces existing groups).",
    {
      node_path: z.string().describe("Path to the node in the scene tree"),
      groups: z.array(z.string()).describe("List of group names the node should belong to"),
    },
    async (params) => sendCmd(godot, "set_node_groups", params),
  );

  server.tool(
    "godot_find_nodes_in_group",
    "Find all nodes belonging to a specific group in the scene.",
    {
      group: z.string().describe("Name of the group to search for"),
      scene_path: z
        .string()
        .optional()
        .describe("Path to a scene file to search in. Uses the currently open scene if omitted."),
    },
    async (params) => sendCmd(godot, "find_nodes_in_group", params),
  );
}
