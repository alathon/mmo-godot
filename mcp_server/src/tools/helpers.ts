import { GodotClient } from "../godot-client.js";

export async function sendCmd(
  godot: GodotClient,
  command: string,
  params: Record<string, unknown> = {},
) {
  try {
    const result = await godot.send(command, params);
    const text =
      typeof result === "string" ? result : JSON.stringify(result, null, 2);
    return { content: [{ type: "text" as const, text }] };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      content: [{ type: "text" as const, text: `Error: ${message}` }],
      isError: true as const,
    };
  }
}

export async function sendCmdAsImage(
  godot: GodotClient,
  command: string,
  params: Record<string, unknown> = {},
) {
  try {
    const result = (await godot.send(command, params)) as {
      data?: string;
      format?: string;
    };
    if (result.data) {
      return {
        content: [
          {
            type: "image" as const,
            data: result.data,
            mimeType: `image/${result.format ?? "png"}` as `image/png`,
          },
        ],
      };
    }
    return {
      content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      content: [{ type: "text" as const, text: `Error: ${message}` }],
      isError: true as const,
    };
  }
}
