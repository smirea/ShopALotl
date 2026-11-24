import { withBearer } from "sync-engine/core";
import type { Config } from "./config";
import { FEEDBACK_ROUTE, feedbackAnswer, fileFeedbackIssue } from "./feedback";

/**
 * `engine` is the sync engine behind `POST /api/sync` and `GET /api/live`, reached only after the owner check, with
 * the `/api` prefix already stripped. The Worker forwards to its Durable Object, the Bun server runs a space
 * in-process. `Upgraded` is what a host answers once it has taken over the socket (Bun returns nothing after
 * `server.upgrade`); the Worker always has a Response.
 */
export type App<Upgraded = never> = {
  config: Config;
  engine(request: Request): Promise<Response | Upgraded>;
};

const error = (status: number, message: string) =>
  Response.json({ ok: false, error: message }, { status });

const encoder = new TextEncoder();
const digest = async (text: string) =>
  new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(text)));

/** Compares SHA-256 digests byte by byte without stopping early, so the time taken says nothing about the token. */
async function isOwner(request: Request, token: string): Promise<boolean> {
  const given = /^Bearer (.+)$/i.exec(request.headers.get("authorization") ?? "")?.[1];
  if (!given) return false;
  const [a, b] = await Promise.all([digest(given), digest(token)]);
  let difference = 0;
  for (let index = 0; index < a.length; index++) difference |= a[index]! ^ b[index]!;
  return difference === 0;
}

/**
 * Bun 1.4 resets the connection when a response leaves before the request body was read, so a client would see
 * ECONNRESET, which reads as offline, instead of the answer that tells it why.
 */
async function drain(request: Request): Promise<void> {
  if (request.body && !request.bodyUsed) await request.arrayBuffer();
}

const ENGINE_ROUTES = new Set(["POST /api/sync", "GET /api/live"]);

/**
 * Every route, as one fetch handler: `dev.ts` serves it with Bun and `worker.ts` on Cloudflare, so it stays free of
 * Bun and Node APIs. `GET /status` is open; everything under `/api` needs the owner token: the two sync routes and `POST /api/feedback`. The prefix leaves `/` free
 * for a web client served by the same Worker.
 */
export async function handle<Upgraded = never>(
  request: Request,
  app: App<Upgraded>,
): Promise<Response | Upgraded> {
  const url = new URL(request.url);
  const route = `${request.method} ${url.pathname}`;
  if (route === "GET /status")
    return Response.json({ ok: true, service: "shopalotl", environment: app.config.environment });
  if (url.pathname !== "/api" && !url.pathname.startsWith("/api/")) return error(404, "Not found");
  // `withBearer` only matters for a browser's `/live`, whose token rides in the subprotocol.
  if (!(await isOwner(withBearer(request), app.config.ownerToken))) {
    await drain(request);
    return error(401, "Missing or wrong owner token");
  }
  if (route === FEEDBACK_ROUTE) {
    if (!app.config.githubToken) {
      await drain(request);
      return feedbackAnswer(503, {
        message: "Set GITHUB_TOKEN on the server to file feedback issues.",
      });
    }
    return fileFeedbackIssue(request, app.config.githubToken);
  }
  if (!ENGINE_ROUTES.has(route)) return error(404, "Not found");
  url.pathname = url.pathname.slice("/api".length);
  return app.engine(new Request(url, request));
}
