import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerRuntimeTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_get_game_scene_tree",
    "Get the live scene tree of the currently running game.",
    {},
    async () => sendCmd(godot, "get_game_scene_tree"),
  );

  server.tool(
    "godot_get_game_node_properties",
    "Get properties of a node in the currently running game.",
    {
      node_path: z.string().describe("Absolute node path in the running game scene tree (e.g. '/root/Game/Player')"),
    },
    async (params) => sendCmd(godot, "get_game_node_properties", params),
  );

  server.tool(
    "godot_set_game_node_property",
    "Set a property on a node in the currently running game.",
    {
      node_path: z.string().describe("Absolute node path in the running game scene tree"),
      property: z.string().describe("Name of the property to set"),
      value: z.any().describe("The new value for the property"),
    },
    async (params) => sendCmd(godot, "set_game_node_property", params),
  );

  server.tool(
    "godot_capture_frames",
    "Capture a series of screenshots from the running game.",
    {
      count: z.number().describe("Number of frames to capture"),
      interval: z.number().optional().describe("Interval between captures in milliseconds. Defaults to 100ms."),
    },
    async (params) => sendCmd(godot, "capture_frames", params),
  );

  server.tool(
    "godot_record_frames",
    "Record a video of the running game for a specified duration.",
    {
      duration: z.number().describe("Duration to record in seconds"),
      fps: z.number().optional().describe("Frames per second for the recording. Defaults to 30."),
    },
    async (params) => sendCmd(godot, "record_frames", params),
  );

  server.tool(
    "godot_monitor_properties",
    "Monitor property values on a game node over time.",
    {
      node_path: z.string().describe("Absolute node path in the running game scene tree"),
      properties: z.array(z.string()).describe("List of property names to monitor"),
      duration: z.number().optional().describe("How long to monitor in seconds. Defaults to 1.0."),
      interval: z.number().optional().describe("Sampling interval in milliseconds. Defaults to 100."),
    },
    async (params) => sendCmd(godot, "monitor_properties", params),
  );

  server.tool(
    "godot_execute_game_script",
    "Execute a GDScript snippet in the context of the running game.",
    {
      script: z.string().describe("GDScript code to execute in the running game context"),
    },
    async (params) => sendCmd(godot, "execute_game_script", params),
  );

  server.tool(
    "godot_start_recording",
    "Start recording gameplay for later replay.",
    {
      fps: z.number().optional().describe("Target frames per second for recording. Defaults to 30."),
      duration: z.number().optional().describe("Maximum recording duration in seconds. No limit if omitted."),
    },
    async (params) => sendCmd(godot, "start_recording", params),
  );

  server.tool(
    "godot_stop_recording",
    "Stop the current gameplay recording.",
    {},
    async () => sendCmd(godot, "stop_recording"),
  );

  server.tool(
    "godot_replay_recording",
    "Replay a previously recorded gameplay session.",
    {
      file_path: z
        .string()
        .optional()
        .describe("Path to the recording file to replay. Uses the most recent recording if omitted."),
    },
    async (params) => sendCmd(godot, "replay_recording", params),
  );

  server.tool(
    "godot_find_nodes_by_script",
    "Find all nodes in the running game that use a specific script.",
    {
      script_path: z.string().describe("Path to the script file relative to res://"),
    },
    async (params) => sendCmd(godot, "find_nodes_by_script", params),
  );

  server.tool(
    "godot_get_autoload",
    "Get autoload singleton instances from the running game.",
    {
      name: z
        .string()
        .optional()
        .describe("Name of a specific autoload singleton. Returns all autoloads if omitted."),
    },
    async (params) => sendCmd(godot, "get_autoload", params),
  );

  server.tool(
    "godot_batch_get_properties",
    "Get properties from multiple nodes in the running game in a single call.",
    {
      nodes: z
        .array(
          z.object({
            path: z.string().describe("Absolute node path"),
            properties: z.array(z.string()).describe("Property names to retrieve"),
          }),
        )
        .describe("List of node/property requests"),
    },
    async (params) => sendCmd(godot, "batch_get_properties", params),
  );

  server.tool(
    "godot_find_ui_elements",
    "Find UI Control nodes in the running game, optionally filtered by type or text.",
    {
      type: z.string().optional().describe("Control node type to filter by (e.g. 'Button', 'Label')"),
      text: z.string().optional().describe("Text content to filter by"),
    },
    async (params) => sendCmd(godot, "find_ui_elements", params),
  );

  server.tool(
    "godot_click_button_by_text",
    "Click a Button node in the running game that has the specified text.",
    {
      text: z.string().describe("Text of the button to click"),
      exact: z.boolean().optional().describe("Whether to require an exact text match. Defaults to false (substring match)."),
    },
    async (params) => sendCmd(godot, "click_button_by_text", params),
  );

  server.tool(
    "godot_wait_for_node",
    "Wait until a node appears in the running game scene tree.",
    {
      node_path: z.string().describe("Absolute node path to wait for"),
      timeout: z.number().optional().describe("Maximum wait time in seconds. Defaults to 5.0."),
    },
    async (params) => sendCmd(godot, "wait_for_node", params),
  );

  server.tool(
    "godot_find_nearby_nodes",
    "Find nodes within a radius of a given node in the running game.",
    {
      node_path: z.string().describe("Absolute path to the reference node"),
      radius: z.number().optional().describe("Search radius in world units. Defaults to 100."),
      type: z.string().optional().describe("Filter results by node type (e.g. 'CharacterBody2D')"),
    },
    async (params) => sendCmd(godot, "find_nearby_nodes", params),
  );

  server.tool(
    "godot_navigate_to",
    "Command a NavigationAgent node to navigate to a target position or node.",
    {
      agent_path: z.string().describe("Absolute path to the NavigationAgent node in the running game"),
      target: z
        .any()
        .describe("Target as a position string (e.g. 'Vector2(100, 200)') or absolute node path"),
    },
    async (params) => sendCmd(godot, "navigate_to", params),
  );

  server.tool(
    "godot_move_to",
    "Move a node to a target position in the running game.",
    {
      node_path: z.string().describe("Absolute path to the node to move"),
      target: z
        .any()
        .describe("Target position as a string (e.g. 'Vector2(100, 200)' or 'Vector3(1, 0, 2)')"),
    },
    async (params) => sendCmd(godot, "move_to", params),
  );
}
