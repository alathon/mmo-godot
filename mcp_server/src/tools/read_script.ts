import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";

export function registerReadScript(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_read_script",
    "Read the contents of a GDScript (.gd), C# (.cs), or shader (.gdshader) file from the Godot project.",
    {
      path: z.string().describe("Path to the script file relative to res:// (e.g. 'src/client/player.gd')"),
    },
    async ({ path }) => {
      try {
        const result = (await godot.send("read_script", { path })) as {
          path?: string;
          content?: string;
          line_count?: number;
        };

        const header = `# ${result.path ?? path}  (${result.line_count ?? "?"} lines)`;

        return {
          content: [
            {
              type: "text" as const,
              text: `${header}\n\n${result.content ?? ""}`,
            },
          ],
        };
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        return {
          content: [{ type: "text" as const, text: `Error: ${message}` }],
          isError: true,
        };
      }
    },
  );
}
