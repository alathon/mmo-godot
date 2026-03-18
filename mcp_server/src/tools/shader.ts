import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerShaderTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_create_shader",
    "Create a new shader file in the Godot project.",
    {
      path: z
        .string()
        .describe("Path for the new shader file relative to res:// (e.g. 'assets/shaders/wave.gdshader')"),
      content: z.string().optional().describe("Initial shader source code. Defaults to a basic template."),
    },
    async (params) => sendCmd(godot, "create_shader", params),
  );

  server.tool(
    "godot_read_shader",
    "Read the source code of a shader file.",
    {
      path: z.string().describe("Path to the shader file relative to res://"),
    },
    async (params) => sendCmd(godot, "read_shader", params),
  );

  server.tool(
    "godot_edit_shader",
    "Replace the source code of an existing shader file.",
    {
      path: z.string().describe("Path to the shader file relative to res://"),
      content: z.string().describe("The new shader source code"),
    },
    async (params) => sendCmd(godot, "edit_shader", params),
  );

  server.tool(
    "godot_assign_shader_material",
    "Create a ShaderMaterial and assign it to a node.",
    {
      node_path: z.string().describe("Path to the node to assign the material to"),
      shader_path: z.string().describe("Path to the shader file relative to res://"),
    },
    async (params) => sendCmd(godot, "assign_shader_material", params),
  );

  server.tool(
    "godot_set_shader_param",
    "Set a uniform parameter value on a node's ShaderMaterial.",
    {
      node_path: z.string().describe("Path to the node with a ShaderMaterial"),
      param_name: z.string().describe("Name of the shader uniform parameter"),
      value: z
        .any()
        .describe("Value for the parameter (use string representation for Godot types)"),
    },
    async (params) => sendCmd(godot, "set_shader_param", params),
  );

  server.tool(
    "godot_get_shader_params",
    "Get all uniform parameters and their current values from a node's ShaderMaterial.",
    {
      node_path: z.string().describe("Path to the node with a ShaderMaterial"),
    },
    async (params) => sendCmd(godot, "get_shader_params", params),
  );
}
