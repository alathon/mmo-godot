import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerInputMapTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_get_input_actions",
    "Get all input actions defined in the project's InputMap.",
    {
      filter: z
        .string()
        .optional()
        .describe("Optional substring filter to narrow down action names (e.g. 'ui_' or 'player_')"),
    },
    async (params) => sendCmd(godot, "get_input_actions", params),
  );

  server.tool(
    "godot_set_input_action",
    "Create or update an input action with the given events.",
    {
      action_name: z.string().describe("Name of the action to create or update (e.g. 'jump', 'ui_accept')"),
      events: z
        .array(z.record(z.any()))
        .describe(
          "List of input event objects. Each event should specify a type and relevant properties " +
            "(e.g. { type: 'key', keycode: 32 } for spacebar, { type: 'joypad_button', button_index: 0 })",
        ),
      deadzone: z
        .number()
        .optional()
        .describe("Deadzone threshold for analog inputs (0.0–1.0). Defaults to 0.5."),
    },
    async (params) => sendCmd(godot, "set_input_action", params),
  );
}
