import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd, sendCmdAsImage } from "./helpers.js";

export function registerResourceTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_read_resource",
    "Read the properties of a Godot resource file (.tres, .res).",
    {
      path: z.string().describe("Path to the resource file relative to res://"),
    },
    async (params) => sendCmd(godot, "read_resource", params),
  );

  server.tool(
    "godot_edit_resource",
    "Edit properties of a Godot resource file.",
    {
      path: z.string().describe("Path to the resource file relative to res://"),
      properties: z
        .record(z.any())
        .describe("Object mapping property names to their new values"),
    },
    async (params) => sendCmd(godot, "edit_resource", params),
  );

  server.tool(
    "godot_create_resource",
    "Create a new Godot resource file.",
    {
      path: z.string().describe("Path for the new resource file relative to res:// (e.g. 'assets/my_material.tres')"),
      resource_type: z.string().describe("Godot resource type to create (e.g. 'StandardMaterial3D', 'AudioStreamMP3')"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Initial property values to set on the new resource"),
    },
    async (params) => sendCmd(godot, "create_resource", params),
  );

  server.tool(
    "godot_get_resource_preview",
    "Get a preview thumbnail image of a resource.",
    {
      path: z.string().describe("Path to the resource file relative to res://"),
    },
    async (params) => sendCmdAsImage(godot, "get_resource_preview", params),
  );
}
