import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerThemeTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_create_theme",
    "Create a new Godot Theme resource file.",
    {
      path: z.string().describe("Path for the new theme file relative to res:// (e.g. 'assets/ui/main_theme.tres')"),
    },
    async (params) => sendCmd(godot, "create_theme", params),
  );

  server.tool(
    "godot_set_theme_color",
    "Set a color value in a theme for a specific element type.",
    {
      theme_path: z.string().describe("Path to the theme resource file relative to res://"),
      element_type: z.string().describe("The Control type this color applies to (e.g. 'Button', 'Label')"),
      color_name: z.string().describe("Name of the color property (e.g. 'font_color', 'icon_hover_color')"),
      r: z.number().describe("Red channel (0.0–1.0)"),
      g: z.number().describe("Green channel (0.0–1.0)"),
      b: z.number().describe("Blue channel (0.0–1.0)"),
      a: z.number().optional().describe("Alpha channel (0.0–1.0). Defaults to 1.0."),
    },
    async (params) => sendCmd(godot, "set_theme_color", params),
  );

  server.tool(
    "godot_set_theme_constant",
    "Set an integer constant in a theme for a specific element type.",
    {
      theme_path: z.string().describe("Path to the theme resource file relative to res://"),
      element_type: z.string().describe("The Control type this constant applies to"),
      constant_name: z.string().describe("Name of the constant (e.g. 'separation', 'margin_left')"),
      value: z.number().describe("Integer value for the constant"),
    },
    async (params) => sendCmd(godot, "set_theme_constant", params),
  );

  server.tool(
    "godot_set_theme_font_size",
    "Set a font size value in a theme for a specific element type.",
    {
      theme_path: z.string().describe("Path to the theme resource file relative to res://"),
      element_type: z.string().describe("The Control type this font size applies to"),
      font_size_name: z.string().describe("Name of the font size property (e.g. 'font_size')"),
      size: z.number().describe("Font size in pixels"),
    },
    async (params) => sendCmd(godot, "set_theme_font_size", params),
  );

  server.tool(
    "godot_set_theme_stylebox",
    "Set a StyleBox in a theme for a specific element type and state.",
    {
      theme_path: z.string().describe("Path to the theme resource file relative to res://"),
      element_type: z.string().describe("The Control type this stylebox applies to (e.g. 'Button')"),
      stylebox_name: z.string().describe("Name of the stylebox (e.g. 'normal', 'hover', 'pressed')"),
      stylebox_type: z
        .string()
        .describe("Type of StyleBox to create (e.g. 'StyleBoxFlat', 'StyleBoxTexture', 'StyleBoxEmpty')"),
      properties: z
        .record(z.any())
        .optional()
        .describe("Properties to set on the new StyleBox (e.g. { bg_color: 'Color(1,0,0,1)' })"),
    },
    async (params) => sendCmd(godot, "set_theme_stylebox", params),
  );

  server.tool(
    "godot_get_theme_info",
    "Get all entries defined in a Godot theme resource.",
    {
      theme_path: z.string().describe("Path to the theme resource file relative to res://"),
    },
    async (params) => sendCmd(godot, "get_theme_info", params),
  );
}
