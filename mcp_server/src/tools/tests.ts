import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerTestTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_run_test_scenario",
    "Run a GDScript test scenario file and return the results.",
    {
      scenario_path: z
        .string()
        .describe("Path to the test scenario script or scene relative to res://"),
      params: z
        .record(z.any())
        .optional()
        .describe("Optional parameters to pass to the test scenario"),
    },
    async (params) => sendCmd(godot, "run_test_scenario", params),
  );

  server.tool(
    "godot_assert_node_state",
    "Assert that a node property has an expected value in the running game.",
    {
      node_path: z.string().describe("Absolute node path in the running game"),
      property: z.string().describe("Property name to check"),
      expected_value: z.any().describe("Expected value of the property"),
      message: z.string().optional().describe("Optional assertion failure message"),
    },
    async (params) => sendCmd(godot, "assert_node_state", params),
  );

  server.tool(
    "godot_assert_screen_text",
    "Assert that a specific text string appears somewhere on the game screen.",
    {
      text: z.string().describe("Text to look for on screen"),
      exact: z
        .boolean()
        .optional()
        .describe("Whether to require an exact match. Defaults to false (substring match)."),
      message: z.string().optional().describe("Optional assertion failure message"),
    },
    async (params) => sendCmd(godot, "assert_screen_text", params),
  );

  server.tool(
    "godot_run_stress_test",
    "Run a stress test scenario to measure performance under load.",
    {
      config: z
        .object({
          duration: z.number().optional().describe("Test duration in seconds"),
          spawn_count: z.number().optional().describe("Number of objects to spawn"),
          scenario: z.string().optional().describe("Path to a custom stress test scene"),
        })
        .optional()
        .describe("Stress test configuration"),
    },
    async (params) => sendCmd(godot, "run_stress_test", params),
  );

  server.tool(
    "godot_get_test_report",
    "Get the results of the most recently run test or stress test.",
    {},
    async () => sendCmd(godot, "get_test_report"),
  );
}
