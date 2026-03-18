import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { GodotClient } from "../godot-client.js";
import { registerReadScript } from "./read_script.js";
import { registerScriptTools } from "./scripts.js";
import { registerSceneTools } from "./scenes.js";
import { registerNodeTools } from "./nodes.js";
import { registerProjectTools } from "./project.js";
import { registerEditorTools } from "./editor.js";
import { registerResourceTools } from "./resources.js";
import { registerInputTools } from "./input.js";
import { registerRuntimeTools } from "./runtime.js";
import { registerAnimationTools } from "./animation.js";
import { registerAnimationTreeTools } from "./animation_tree.js";
import { registerTilemapTools } from "./tilemap.js";
import { registerThemeTools } from "./theme.js";
import { registerPhysicsTools } from "./physics.js";
import { registerShaderTools } from "./shader.js";
import { registerAudioTools } from "./audio.js";
import { registerNavigationTools } from "./navigation.js";
import { registerParticleTools } from "./particles.js";
import { registerProfilingTools } from "./profiling.js";
import { registerBatchTools } from "./batch.js";
import { registerAnalysisTools } from "./analysis.js";
import { registerExportTools } from "./export.js";
import { registerInputMapTools } from "./input_map.js";
import { registerScene3DTools } from "./scene_3d.js";
import { registerTestTools } from "./tests.js";

/**
 * Register all typed tools with the MCP server.
 * Add new tool registrations here as they are implemented.
 */
export function registerAllTools(server: McpServer, godot: GodotClient) {
  registerReadScript(server, godot);
  registerScriptTools(server, godot);
  registerSceneTools(server, godot);
  registerNodeTools(server, godot);
  registerProjectTools(server, godot);
  registerEditorTools(server, godot);
  registerResourceTools(server, godot);
  registerInputTools(server, godot);
  registerRuntimeTools(server, godot);
  registerAnimationTools(server, godot);
  registerAnimationTreeTools(server, godot);
  registerTilemapTools(server, godot);
  registerThemeTools(server, godot);
  registerPhysicsTools(server, godot);
  registerShaderTools(server, godot);
  registerAudioTools(server, godot);
  registerNavigationTools(server, godot);
  registerParticleTools(server, godot);
  registerProfilingTools(server, godot);
  registerBatchTools(server, godot);
  registerAnalysisTools(server, godot);
  registerExportTools(server, godot);
  registerInputMapTools(server, godot);
  registerScene3DTools(server, godot);
  registerTestTools(server, godot);
}
