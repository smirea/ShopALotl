/**
 * The local server: `bun run start:server`. It runs the same `handle` as the Worker over a space in one SQLite file
 * per checkout, so the main checkout and every worktree keep their own data.
 */
import { mkdirSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { bunSqlite } from "sync-engine/bun-sqlite";
import { createSpace, handleSync, LIVE_PROTOCOL } from "sync-engine/core";
import { handle } from "./api";
import { parseConfig } from "./config";
import env from "./env";
import { schema } from "./schema";

const root = join(import.meta.dir, "..");
const file = join(root, ".data", `${basename(root)}.sqlite`);
mkdirSync(dirname(file), { recursive: true });

const config = parseConfig(env);
const space = createSpace(bunSqlite(file), schema);
space.migrate();

const server = Bun.serve({
  development: config.environment === "development",
  port: env.API_PORT,
  fetch: (request, server) =>
    handle<undefined>(request, {
      config,
      async engine(request) {
        if (request.headers.get("upgrade")?.toLowerCase() === "websocket") {
          // Echo the subprotocol only when offered: the Swift client offers none and fails the handshake on an echo.
          const offered = request.headers
            .get("sec-websocket-protocol")
            ?.split(",")
            .some((protocol) => protocol.trim() === LIVE_PROTOCOL);
          const headers = offered ? { "Sec-WebSocket-Protocol": LIVE_PROTOCOL } : undefined;
          if (server.upgrade(request, { headers, data: undefined })) return undefined;
          return Response.json(
            { ok: false, error: "Expected a WebSocket upgrade" },
            { status: 400 },
          );
        }
        const before = space.head();
        const response = await handleSync(space, request);
        if (space.head() > before) server.publish("live", JSON.stringify({ head: space.head() }));
        return response;
      },
    }),
  websocket: {
    open: (ws) => void ws.subscribe("live"),
    message(ws, message) {
      if (message === "ping") ws.send("pong");
    },
  },
});

console.log(`Server running at ${server.url.href} over ${file}`);
