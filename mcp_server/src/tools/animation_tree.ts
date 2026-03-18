import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerAnimationTreeTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_create_animation_tree",
    "Create an AnimationTree node and configure its root node type.",
    {
      node_path: z.string().describe("Path to attach the AnimationTree (parent or existing node path)"),
      root_type: z
        .string()
        .optional()
        .describe("Root node type for the tree (e.g. 'AnimationNodeStateMachine', 'AnimationNodeBlendTree'). Defaults to 'AnimationNodeStateMachine'."),
    },
    async (params) => sendCmd(godot, "create_animation_tree", params),
  );

  server.tool(
    "godot_get_animation_tree_structure",
    "Get the structure and parameters of an AnimationTree node.",
    {
      node_path: z.string().describe("Path to the AnimationTree node"),
    },
    async (params) => sendCmd(godot, "get_animation_tree_structure", params),
  );

  server.tool(
    "godot_add_state_machine_state",
    "Add a state to an AnimationNodeStateMachine.",
    {
      node_path: z.string().describe("Path to the AnimationTree node"),
      state_machine_path: z
        .string()
        .describe("Path within the tree to the state machine (e.g. 'parameters/state_machine')"),
      state_name: z.string().describe("Name for the new state"),
      animation: z.string().optional().describe("Animation name to play in this state"),
    },
    async (params) => sendCmd(godot, "add_state_machine_state", params),
  );

  server.tool(
    "godot_remove_state_machine_state",
    "Remove a state from an AnimationNodeStateMachine.",
    {
      node_path: z.string().describe("Path to the AnimationTree node"),
      state_machine_path: z.string().describe("Path within the tree to the state machine"),
      state_name: z.string().describe("Name of the state to remove"),
    },
    async (params) => sendCmd(godot, "remove_state_machine_state", params),
  );

  server.tool(
    "godot_add_state_machine_transition",
    "Add a transition between two states in an AnimationNodeStateMachine.",
    {
      node_path: z.string().describe("Path to the AnimationTree node"),
      state_machine_path: z.string().describe("Path within the tree to the state machine"),
      from_state: z.string().describe("Name of the source state"),
      to_state: z.string().describe("Name of the destination state"),
    },
    async (params) => sendCmd(godot, "add_state_machine_transition", params),
  );

  server.tool(
    "godot_remove_state_machine_transition",
    "Remove a transition between two states in an AnimationNodeStateMachine.",
    {
      node_path: z.string().describe("Path to the AnimationTree node"),
      state_machine_path: z.string().describe("Path within the tree to the state machine"),
      from_state: z.string().describe("Name of the source state"),
      to_state: z.string().describe("Name of the destination state"),
    },
    async (params) => sendCmd(godot, "remove_state_machine_transition", params),
  );

  server.tool(
    "godot_set_blend_tree_node",
    "Add or configure a node in an AnimationNodeBlendTree.",
    {
      node_path: z.string().describe("Path to the AnimationTree node"),
      blend_tree_path: z.string().describe("Path within the tree to the blend tree"),
      node_type: z
        .string()
        .describe("Type of blend tree node (e.g. 'AnimationNodeAnimation', 'AnimationNodeBlend2')"),
      node_name: z.string().describe("Name for this blend tree node"),
      position: z
        .any()
        .optional()
        .describe("Position in the blend tree editor as a Vector2 string (e.g. 'Vector2(0, 0)')"),
    },
    async (params) => sendCmd(godot, "set_blend_tree_node", params),
  );

  server.tool(
    "godot_set_tree_parameter",
    "Set a parameter value on an AnimationTree.",
    {
      node_path: z.string().describe("Path to the AnimationTree node"),
      parameter: z
        .string()
        .describe("Parameter path (e.g. 'parameters/state_machine/current_node')"),
      value: z.any().describe("The new value for the parameter"),
    },
    async (params) => sendCmd(godot, "set_tree_parameter", params),
  );
}
