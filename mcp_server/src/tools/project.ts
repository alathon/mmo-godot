import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { GodotClient } from "../godot-client.js";
import { sendCmd } from "./helpers.js";

export function registerProjectTools(server: McpServer, godot: GodotClient) {
  server.tool(
    "godot_get_project_info",
    "Get general information about the currently open Godot project.",
    {},
    async () => sendCmd(godot, "get_project_info"),
  );

  server.tool(
    "godot_get_filesystem_tree",
    "Get the project filesystem directory tree, optionally starting from a subdirectory.",
    {
      path: z
        .string()
        .optional()
        .describe("Root path to list relative to res://. Defaults to res:// (entire project)."),
      extensions: z
        .array(z.string())
        .optional()
        .describe("Filter by file extensions (e.g. ['gd', 'tscn']). Returns all files if omitted."),
    },
    async (params) => sendCmd(godot, "get_filesystem_tree", params),
  );

  server.tool(
    "godot_search_files",
    "Search for files in the project by filename pattern.",
    {
      query: z.string().describe("Search query / pattern to match filenames against"),
      path: z
        .string()
        .optional()
        .describe("Directory to search in relative to res://. Defaults to entire project."),
      extensions: z
        .array(z.string())
        .optional()
        .describe("Restrict search to these file extensions (e.g. ['gd', 'tscn'])"),
    },
    async (params) => sendCmd(godot, "search_files", params),
  );

  server.tool(
    "godot_search_in_files",
    "Search for a text pattern inside file contents across the project.",
    {
      query: z.string().describe("Text or regex pattern to search for inside files"),
      path: z
        .string()
        .optional()
        .describe("Directory to search in relative to res://. Defaults to entire project."),
      extensions: z
        .array(z.string())
        .optional()
        .describe("Restrict search to these file extensions (e.g. ['gd', 'tscn'])"),
      case_sensitive: z.boolean().optional().describe("Whether the search is case-sensitive. Defaults to false."),
    },
    async (params) => sendCmd(godot, "search_in_files", params),
  );

  server.tool(
    "godot_get_project_settings",
    "Get project settings (project.godot), optionally filtered by section.",
    {
      section: z
        .string()
        .optional()
        .describe("Settings section prefix to filter by (e.g. 'rendering', 'physics', 'application')"),
    },
    async (params) => sendCmd(godot, "get_project_settings", params),
  );

  server.tool(
    "godot_set_project_setting",
    "Set a project setting value in project.godot.",
    {
      setting: z.string().describe("Dot-separated setting path (e.g. 'application/config/name')"),
      value: z
        .any()
        .describe("The new value for the setting"),
    },
    async (params) => sendCmd(godot, "set_project_setting", params),
  );

  server.tool(
    "godot_uid_to_project_path",
    "Convert a Godot UID to its corresponding project file path.",
    {
      uid: z.string().describe("The Godot UID string (e.g. 'uid://abc123')"),
    },
    async (params) => sendCmd(godot, "uid_to_project_path", params),
  );

  server.tool(
    "godot_project_path_to_uid",
    "Convert a project file path to its corresponding Godot UID.",
    {
      path: z.string().describe("Path to the resource relative to res://"),
    },
    async (params) => sendCmd(godot, "project_path_to_uid", params),
  );

  server.tool(
    "godot_add_autoload",
    "Add an autoload singleton to the project settings.",
    {
      name: z.string().describe("Name for the autoload singleton (e.g. 'GameManager')"),
      path: z.string().describe("Path to the script or scene to autoload relative to res://"),
      singleton: z.boolean().optional().describe("Whether to enable singleton mode. Defaults to true."),
    },
    async (params) => sendCmd(godot, "add_autoload", params),
  );

  server.tool(
    "godot_remove_autoload",
    "Remove an autoload singleton from the project settings.",
    {
      name: z.string().describe("Name of the autoload singleton to remove"),
    },
    async (params) => sendCmd(godot, "remove_autoload", params),
  );
}
