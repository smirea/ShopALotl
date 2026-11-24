import type { DurableObjectNamespace, DurableObjectState } from "@cloudflare/workers-types";
import { SpaceObject } from "sync-engine/cloudflare";
import { handle } from "./api";
import { parseConfig, type Config, type Settings } from "./config";
import { schema } from "./schema";

type Env = Settings & { SPACE: DurableObjectNamespace };

/** The owner's one space: a SQLite-backed Durable Object holding every synced table. */
export class Space extends SpaceObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env, schema);
  }
}

const configs = new WeakMap<Env, Config>();
/** Parsed once per bindings object, which the runtime keeps for the isolate's life. */
function configOf(env: Env): Config {
  let config = configs.get(env);
  if (!config) {
    config = parseConfig(env);
    configs.set(env, config);
  }
  return config;
}

/** The stub speaks the Workers Request and Response types, which this tsconfig's Bun globals do not know. */
const owner = (env: Env) =>
  env.SPACE.get(env.SPACE.idFromName("owner")) as unknown as {
    fetch(input: Request): Promise<Response>;
  };

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      // Before routing, so a misconfigured deploy fails every request and logs the missing setting.
      const config = configOf(env);
      return await handle(request, { config, engine: (request) => owner(env).fetch(request) });
    } catch (error) {
      console.error(error);
      return Response.json({ ok: false, error: "Internal error" }, { status: 500 });
    }
  },
};
