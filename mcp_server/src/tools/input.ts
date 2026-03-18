import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerInputTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_simulate_key",
    "Simulate a keyboard key press/release in the running game.",
    {
      keycode: z
        .number()
        .describe("Godot Key enum value (e.g. KEY_SPACE = 32, KEY_W = 87). See Godot's Key enum."),
      pressed: z.boolean().optional().describe("Whether the key is pressed (true) or released (false). Defaults to true."),
      modifiers: z
        .object({
          shift: z.boolean().optional(),
          ctrl: z.boolean().optional(),
          alt: z.boolean().optional(),
          meta: z.boolean().optional(),
        })
        .optional()
        .describe("Modifier keys to hold during the event"),
    },
    async (params) => sendCmd(godot, "simulate_key", params),
  );

  server.tool(
    "godot_simulate_mouse_click",
    "Simulate a mouse button click in the running game.",
    {
      x: z.number().describe("X coordinate in screen pixels"),
      y: z.number().describe("Y coordinate in screen pixels"),
      button: z
        .number()
        .optional()
        .describe("Mouse button index (1=LEFT, 2=RIGHT, 3=MIDDLE). Defaults to 1 (left click)."),
      pressed: z.boolean().optional().describe("Whether the button is pressed (true) or released (false). Defaults to true."),
    },
    async (params) => sendCmd(godot, "simulate_mouse_click", params),
  );

  server.tool(
    "godot_simulate_mouse_move",
    "Simulate mouse movement in the running game.",
    {
      x: z.number().describe("Target X coordinate in screen pixels"),
      y: z.number().describe("Target Y coordinate in screen pixels"),
      relative_x: z.number().optional().describe("Relative X movement delta"),
      relative_y: z.number().optional().describe("Relative Y movement delta"),
    },
    async (params) => sendCmd(godot, "simulate_mouse_move", params),
  );

  server.tool(
    "godot_simulate_action",
    "Simulate an InputMap action in the running game.",
    {
      action: z.string().describe("Name of the InputMap action to simulate (e.g. 'ui_accept', 'move_left')"),
      pressed: z.boolean().optional().describe("Whether the action is pressed (true) or released (false). Defaults to true."),
      strength: z.number().optional().describe("Action strength (0.0–1.0). Defaults to 1.0."),
    },
    async (params) => sendCmd(godot, "simulate_action", params),
  );

  server.tool(
    "godot_simulate_sequence",
    "Simulate a sequence of input events in the running game.",
    {
      steps: z
        .array(
          z.object({
            type: z
              .enum(["key", "mouse_click", "mouse_move", "action", "wait"])
              .describe("Type of input event"),
            delay: z.number().optional().describe("Delay in milliseconds before this step"),
          }).passthrough(),
        )
        .describe("Ordered list of input steps to simulate"),
    },
    async (params) => sendCmd(godot, "simulate_sequence", params),
  );
}
