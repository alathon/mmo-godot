import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerPhysicsTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_setup_collision",
    "Add and configure a CollisionShape to a physics body node.",
    {
      node_path: z.string().describe("Path to the physics body node (e.g. CharacterBody2D, Area2D)"),
      shape_type: z
        .string()
        .describe("Collision shape type (e.g. 'RectangleShape2D', 'CircleShape2D', 'CapsuleShape3D')"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Properties to set on the shape (e.g. { size: 'Vector2(32,32)' })"),
    },
    async (params) => sendCmd(godot, "setup_collision", params),
  );

  server.tool(
    "godot_set_physics_layers",
    "Set collision layer and mask for a physics node.",
    {
      node_path: z.string().describe("Path to the physics node"),
      layer: z
        .number()
        .optional()
        .describe("Collision layer bitmask (which layers this object is on)"),
      mask: z
        .number()
        .optional()
        .describe("Collision mask bitmask (which layers this object collides with)"),
    },
    async (params) => sendCmd(godot, "set_physics_layers", params),
  );

  server.tool(
    "godot_get_physics_layers",
    "Get the physics layer names defined in the project settings.",
    {},
    async () => sendCmd(godot, "get_physics_layers"),
  );

  server.tool(
    "godot_add_raycast",
    "Add a RayCast2D or RayCast3D node to a parent node.",
    {
      parent_path: z.string().describe("Path to the parent node"),
      name: z.string().optional().describe("Name for the new RayCast node"),
      target_position: z
        .string()
        .optional()
        .describe("Target position as a Vector string (e.g. 'Vector2(0, 50)')"),
      collision_mask: z
        .number()
        .optional()
        .describe("Bitmask for which physics layers to detect"),
    },
    async (params) => sendCmd(godot, "add_raycast", params),
  );

  server.tool(
    "godot_setup_physics_body",
    "Configure properties of a physics body node.",
    {
      node_path: z.string().describe("Path to the physics body node"),
      body_type: z
        .string()
        .describe("Physics body type: 'static', 'rigid', 'character', 'kinematic', 'area'"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Properties to configure on the physics body"),
    },
    async (params) => sendCmd(godot, "setup_physics_body", params),
  );

  server.tool(
    "godot_get_collision_info",
    "Get collision layer/mask settings and shape info for a physics node.",
    {
      node_path: z.string().describe("Path to the physics node"),
    },
    async (params) => sendCmd(godot, "get_collision_info", params),
  );
}
