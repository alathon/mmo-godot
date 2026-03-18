import { WebSocketServer, WebSocket } from "ws";
import { EventEmitter } from "events";

export interface JsonRpcRequest {
  jsonrpc: "2.0";
  id: number;
  method: string;
  params: Record<string, unknown>;
}

export interface JsonRpcSuccessResponse {
  jsonrpc: "2.0";
  id: number;
  result: unknown;
}

export interface JsonRpcErrorResponse {
  jsonrpc: "2.0";
  id: number;
  error: {
    code: number;
    message: string;
    data?: unknown;
  };
}

type JsonRpcResponse = JsonRpcSuccessResponse | JsonRpcErrorResponse;

interface PendingRequest {
  resolve: (value: unknown) => void;
  reject: (reason: Error) => void;
  timer: ReturnType<typeof setTimeout>;
}

const DEFAULT_PORT = 6505;
const REQUEST_TIMEOUT_MS = 30000;

/**
 * Runs a WebSocket **server** on the given port.
 * The Godot MCP Pro addon acts as a WebSocket client and connects to us.
 */
export class GodotClient extends EventEmitter {
  private wss: WebSocketServer | null = null;
  private godotSocket: WebSocket | null = null;
  private nextId = 1;
  private pending = new Map<number, PendingRequest>();
  private port: number;

  constructor(port = DEFAULT_PORT) {
    super();
    this.port = port;
  }

  get connected(): boolean {
    return this.godotSocket?.readyState === WebSocket.OPEN;
  }

  /** Start listening for Godot to connect. */
  listen(): void {
    this.wss = new WebSocketServer({ port: this.port });

    this.wss.on("listening", () => {
      console.error(`[godot-mcp] WebSocket server listening on port ${this.port}`);
    });

    this.wss.on("connection", (ws) => {
      console.error("[godot-mcp] Godot connected");

      // Only keep one Godot connection at a time
      if (this.godotSocket) {
        this.godotSocket.removeAllListeners();
        this.godotSocket.close();
        this.rejectAllPending("Replaced by new connection");
      }

      this.godotSocket = ws;
      this.emit("connected");

      ws.on("message", (data) => {
        this.handleMessage(data.toString());
      });

      ws.on("close", () => {
        console.error("[godot-mcp] Godot disconnected");
        if (this.godotSocket === ws) {
          this.godotSocket = null;
        }
        this.rejectAllPending("Connection closed");
        this.emit("disconnected");
      });

      ws.on("error", (err) => {
        console.error(`[godot-mcp] WebSocket error: ${err.message}`);
      });
    });

    this.wss.on("error", (err) => {
      console.error(`[godot-mcp] Server error: ${err.message}`);
    });
  }

  stop(): void {
    if (this.godotSocket) {
      this.godotSocket.close();
      this.godotSocket = null;
    }
    if (this.wss) {
      this.wss.close();
      this.wss = null;
    }
    this.rejectAllPending("Server stopped");
  }

  async send(method: string, params: Record<string, unknown> = {}): Promise<unknown> {
    if (!this.connected) {
      throw new Error("Not connected to Godot editor — is the Godot MCP Pro plugin enabled?");
    }

    const id = this.nextId++;
    const request: JsonRpcRequest = {
      jsonrpc: "2.0",
      id,
      method,
      params,
    };

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Request timed out: ${method} (id=${id})`));
      }, REQUEST_TIMEOUT_MS);

      this.pending.set(id, { resolve, reject, timer });
      this.godotSocket!.send(JSON.stringify(request));
    });
  }

  private handleMessage(raw: string): void {
    let msg: JsonRpcResponse;
    try {
      msg = JSON.parse(raw);
    } catch {
      console.error("[godot-mcp] Failed to parse message:", raw.slice(0, 200));
      return;
    }

    // Handle ping — Godot sends pings, we reply with pong
    if ("method" in msg && (msg as unknown as { method: string }).method === "ping") {
      this.godotSocket?.send(
        JSON.stringify({ jsonrpc: "2.0", method: "pong", params: {} }),
      );
      return;
    }

    // Ignore pong
    if ("method" in msg && (msg as unknown as { method: string }).method === "pong") {
      return;
    }

    if (!("id" in msg) || msg.id == null) return;

    const pending = this.pending.get(msg.id);
    if (!pending) return;

    clearTimeout(pending.timer);
    this.pending.delete(msg.id);

    if ("error" in msg) {
      pending.reject(new Error(msg.error.message));
    } else {
      pending.resolve(msg.result);
    }
  }

  private rejectAllPending(reason: string): void {
    for (const [id, pending] of this.pending) {
      clearTimeout(pending.timer);
      pending.reject(new Error(reason));
      this.pending.delete(id);
    }
  }
}
