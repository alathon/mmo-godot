import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerTilemapTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_tilemap_set_cell",
    "Set a single cell in a TileMap layer.",
    {
      node_path: z.string().describe("Path to the TileMap node"),
      layer: z.number().describe("Layer index to modify"),
      x: z.number().describe("Cell X coordinate"),
      y: z.number().describe("Cell Y coordinate"),
      source_id: z.number().describe("TileSet source ID"),
      atlas_coords_x: z.number().describe("Atlas tile X coordinate"),
      atlas_coords_y: z.number().describe("Atlas tile Y coordinate"),
      alternative_tile: z
        .number()
        .optional()
        .describe("Alternative tile ID. Defaults to 0."),
    },
    async (params) => sendCmd(godot, "tilemap_set_cell", params),
  );

  server.tool(
    "godot_tilemap_fill_rect",
    "Fill a rectangular region of a TileMap layer with a tile.",
    {
      node_path: z.string().describe("Path to the TileMap node"),
      layer: z.number().describe("Layer index to modify"),
      x: z.number().describe("Top-left cell X coordinate"),
      y: z.number().describe("Top-left cell Y coordinate"),
      width: z.number().describe("Width of the rectangle in cells"),
      height: z.number().describe("Height of the rectangle in cells"),
      source_id: z.number().describe("TileSet source ID"),
      atlas_coords_x: z.number().describe("Atlas tile X coordinate"),
      atlas_coords_y: z.number().describe("Atlas tile Y coordinate"),
      alternative_tile: z.number().optional().describe("Alternative tile ID. Defaults to 0."),
    },
    async (params) => sendCmd(godot, "tilemap_fill_rect", params),
  );

  server.tool(
    "godot_tilemap_get_cell",
    "Get the tile data for a specific cell in a TileMap layer.",
    {
      node_path: z.string().describe("Path to the TileMap node"),
      layer: z.number().describe("Layer index"),
      x: z.number().describe("Cell X coordinate"),
      y: z.number().describe("Cell Y coordinate"),
    },
    async (params) => sendCmd(godot, "tilemap_get_cell", params),
  );

  server.tool(
    "godot_tilemap_clear",
    "Clear all cells in a TileMap (or a specific layer).",
    {
      node_path: z.string().describe("Path to the TileMap node"),
      layer: z.number().optional().describe("Layer index to clear. Clears all layers if omitted."),
    },
    async (params) => sendCmd(godot, "tilemap_clear", params),
  );

  server.tool(
    "godot_tilemap_get_info",
    "Get information about a TileMap including its TileSet and layer count.",
    {
      node_path: z.string().describe("Path to the TileMap node"),
    },
    async (params) => sendCmd(godot, "tilemap_get_info", params),
  );

  server.tool(
    "godot_tilemap_get_used_cells",
    "Get all cell coordinates that are currently used in a TileMap layer.",
    {
      node_path: z.string().describe("Path to the TileMap node"),
      layer: z.number().optional().describe("Layer index to query. Queries all layers if omitted."),
    },
    async (params) => sendCmd(godot, "tilemap_get_used_cells", params),
  );
}
