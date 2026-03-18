import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerAnimationTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_list_animations",
    "List all animations in an AnimationPlayer node.",
    {
      node_path: z.string().describe("Path to the AnimationPlayer node in the scene tree"),
    },
    async (params) => sendCmd(godot, "list_animations", params),
  );

  server.tool(
    "godot_create_animation",
    "Create a new animation in an AnimationPlayer node.",
    {
      node_path: z.string().describe("Path to the AnimationPlayer node"),
      animation_name: z.string().describe("Name for the new animation"),
      length: z.number().optional().describe("Duration of the animation in seconds. Defaults to 1.0."),
      loop: z.boolean().optional().describe("Whether the animation loops. Defaults to false."),
    },
    async (params) => sendCmd(godot, "create_animation", params),
  );

  server.tool(
    "godot_add_animation_track",
    "Add a track to an existing animation in an AnimationPlayer.",
    {
      node_path: z.string().describe("Path to the AnimationPlayer node"),
      animation_name: z.string().describe("Name of the animation to add the track to"),
      track_type: z
        .string()
        .describe(
          "Type of track (e.g. 'value', 'method', 'bezier', 'audio', 'animation')",
        ),
      track_path: z
        .string()
        .describe(
          "Node path and property for the track (e.g. 'Sprite2D:position' or 'AudioStreamPlayer:stream')",
        ),
    },
    async (params) => sendCmd(godot, "add_animation_track", params),
  );

  server.tool(
    "godot_set_animation_keyframe",
    "Set or insert a keyframe value on an animation track.",
    {
      node_path: z.string().describe("Path to the AnimationPlayer node"),
      animation_name: z.string().describe("Name of the animation"),
      track_index: z.number().describe("Index of the track to add the keyframe to"),
      time: z.number().describe("Time position in seconds for the keyframe"),
      value: z.any().describe("Value for the keyframe"),
    },
    async (params) => sendCmd(godot, "set_animation_keyframe", params),
  );

  server.tool(
    "godot_get_animation_info",
    "Get detailed information about an animation including its tracks and keyframes.",
    {
      node_path: z.string().describe("Path to the AnimationPlayer node"),
      animation_name: z.string().describe("Name of the animation to inspect"),
    },
    async (params) => sendCmd(godot, "get_animation_info", params),
  );

  server.tool(
    "godot_remove_animation",
    "Remove an animation from an AnimationPlayer node.",
    {
      node_path: z.string().describe("Path to the AnimationPlayer node"),
      animation_name: z.string().describe("Name of the animation to remove"),
    },
    async (params) => sendCmd(godot, "remove_animation", params),
  );
}
