import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerAudioTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_get_audio_bus_layout",
    "Get the full audio bus layout including all buses and their effects.",
    {},
    async () => sendCmd(godot, "get_audio_bus_layout"),
  );

  server.tool(
    "godot_add_audio_bus",
    "Add a new audio bus to the project's audio bus layout.",
    {
      name: z.string().describe("Name for the new audio bus (e.g. 'Music', 'SFX')"),
      position: z.number().optional().describe("Position index to insert the bus at. Appends at end if omitted."),
    },
    async (params) => sendCmd(godot, "add_audio_bus", params),
  );

  server.tool(
    "godot_set_audio_bus",
    "Configure properties of an existing audio bus.",
    {
      bus: z.union([z.string(), z.number()]).describe("Bus name or index to modify"),
      volume_db: z.number().optional().describe("Volume in decibels"),
      mute: z.boolean().optional().describe("Whether to mute the bus"),
      solo: z.boolean().optional().describe("Whether to solo the bus"),
      bypass_fx: z.boolean().optional().describe("Whether to bypass effects on the bus"),
      send: z.string().optional().describe("Name of the bus to send output to"),
    },
    async (params) => sendCmd(godot, "set_audio_bus", params),
  );

  server.tool(
    "godot_add_audio_bus_effect",
    "Add an audio effect to a bus.",
    {
      bus_name: z.string().describe("Name of the bus to add the effect to"),
      effect_type: z
        .string()
        .describe("Type of audio effect (e.g. 'AudioEffectReverb', 'AudioEffectCompressor', 'AudioEffectEQ')"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Properties to configure on the new effect"),
    },
    async (params) => sendCmd(godot, "add_audio_bus_effect", params),
  );

  server.tool(
    "godot_add_audio_player",
    "Add an AudioStreamPlayer (2D, 3D, or base) node to the scene.",
    {
      parent_path: z.string().describe("Path to the parent node"),
      name: z.string().optional().describe("Name for the new AudioStreamPlayer node"),
      stream: z.string().optional().describe("Path to an audio stream resource relative to res://"),
      bus: z.string().optional().describe("Name of the audio bus to play through. Defaults to 'Master'."),
      type: z
        .enum(["base", "2d", "3d"])
        .optional()
        .describe("Player type: 'base' (AudioStreamPlayer), '2d', or '3d'. Defaults to 'base'."),
    },
    async (params) => sendCmd(godot, "add_audio_player", params),
  );

  server.tool(
    "godot_get_audio_info",
    "Get information about the audio bus layout or a specific bus.",
    {
      bus_name: z
        .string()
        .optional()
        .describe("Name of a specific bus to get info for. Returns full layout info if omitted."),
    },
    async (params) => sendCmd(godot, "get_audio_info", params),
  );
}
