import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerParticleTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_create_particles",
    "Create a GPUParticles2D or GPUParticles3D node in the scene.",
    {
      parent_path: z.string().describe("Path to the parent node"),
      name: z.string().optional().describe("Name for the new particles node"),
      type: z
        .enum(["2d", "3d"])
        .optional()
        .describe("Whether to create a 2D or 3D particles node. Defaults to '2d'."),
    },
    async (params) => sendCmd(godot, "create_particles", params),
  );

  server.tool(
    "godot_set_particle_material",
    "Assign a process material to a GPUParticles node.",
    {
      node_path: z.string().describe("Path to the GPUParticles node"),
      material_path: z
        .string()
        .describe("Path to a ParticleProcessMaterial resource relative to res://"),
    },
    async (params) => sendCmd(godot, "set_particle_material", params),
  );

  server.tool(
    "godot_set_particle_color_gradient",
    "Set the color gradient on a particle process material.",
    {
      node_path: z.string().describe("Path to the GPUParticles node"),
      stops: z
        .array(
          z.object({
            offset: z.number().describe("Position in the gradient (0.0–1.0)"),
            color: z.string().describe("Color as a Godot Color string (e.g. 'Color(1,0,0,1)')"),
          }),
        )
        .describe("List of gradient color stops"),
    },
    async (params) => sendCmd(godot, "set_particle_color_gradient", params),
  );

  server.tool(
    "godot_apply_particle_preset",
    "Apply a named particle effect preset to a GPUParticles node.",
    {
      node_path: z.string().describe("Path to the GPUParticles node"),
      preset_name: z
        .string()
        .describe("Name of the preset to apply (e.g. 'fire', 'smoke', 'sparkle', 'explosion')"),
    },
    async (params) => sendCmd(godot, "apply_particle_preset", params),
  );

  server.tool(
    "godot_get_particle_info",
    "Get configuration info about a GPUParticles node including its material settings.",
    {
      node_path: z.string().describe("Path to the GPUParticles node"),
    },
    async (params) => sendCmd(godot, "get_particle_info", params),
  );
}
