import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerScene3DTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_add_mesh_instance",
    "Add a MeshInstance3D with a primitive mesh to the scene.",
    {
      parent_path: z.string().describe("Path to the parent node"),
      mesh_type: z
        .string()
        .describe(
          "Type of mesh to create (e.g. 'BoxMesh', 'SphereMesh', 'CylinderMesh', 'PlaneMesh', 'CapsuleMesh')",
        ),
      name: z.string().optional().describe("Name for the new MeshInstance3D node"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Properties to set on the mesh (e.g. { size: 'Vector3(1,1,1)' })"),
    },
    async (params) => sendCmd(godot, "add_mesh_instance", params),
  );

  server.tool(
    "godot_setup_lighting",
    "Add and configure a light node (DirectionalLight3D, OmniLight3D, or SpotLight3D).",
    {
      parent_path: z.string().describe("Path to the parent node"),
      light_type: z
        .string()
        .describe("Type of light to create: 'directional', 'omni', or 'spot'"),
      name: z.string().optional().describe("Name for the new light node"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Light properties to configure (e.g. light_energy, light_color, shadow_enabled)"),
    },
    async (params) => sendCmd(godot, "setup_lighting", params),
  );

  server.tool(
    "godot_set_material_3d",
    "Create and assign a 3D material to a MeshInstance3D node.",
    {
      node_path: z.string().describe("Path to the MeshInstance3D node"),
      material_type: z
        .string()
        .describe("Material type to create (e.g. 'StandardMaterial3D', 'ORMMaterial3D')"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Material properties to set (e.g. albedo_color, roughness, metallic)"),
    },
    async (params) => sendCmd(godot, "set_material_3d", params),
  );

  server.tool(
    "godot_setup_environment",
    "Create and assign a WorldEnvironment node with an Environment resource.",
    {
      parent_path: z.string().describe("Path to the parent node"),
      name: z.string().optional().describe("Name for the WorldEnvironment node"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Environment properties to configure (e.g. background_mode, ambient_light_color, fog_enabled)"),
    },
    async (params) => sendCmd(godot, "setup_environment", params),
  );

  server.tool(
    "godot_setup_camera_3d",
    "Add and configure a Camera3D node.",
    {
      parent_path: z.string().describe("Path to the parent node"),
      name: z.string().optional().describe("Name for the Camera3D node"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Camera properties to configure (e.g. fov, near, far, current)"),
    },
    async (params) => sendCmd(godot, "setup_camera_3d", params),
  );

  server.tool(
    "godot_add_gridmap",
    "Add a GridMap node to the scene with an optional MeshLibrary.",
    {
      parent_path: z.string().describe("Path to the parent node"),
      name: z.string().optional().describe("Name for the GridMap node"),
      mesh_library_path: z
        .string()
        .optional()
        .describe("Path to a MeshLibrary resource relative to res://"),
    },
    async (params) => sendCmd(godot, "add_gridmap", params),
  );
}
