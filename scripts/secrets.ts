/**
 * The one bridge from env-manager project `shopalotl` to the Worker, GitHub, and the app's production build settings.
 * Never prints a value: it logs key names only and hands values to child processes on stdin or in their environment.
 *
 *   bun scripts/secrets.ts push     the Worker secrets from env-manager prod, once the Worker exists
 *   bun scripts/secrets.ts deploy   wrangler deploy with prod's Cloudflare credentials
 *   bun scripts/secrets.ts github   the deploy and TestFlight credentials and the app's production settings as
 *                                   repository secrets
 *   bun scripts/secrets.ts check    drift between env-manager prod, the Worker, and GitHub
 *   bun scripts/secrets.ts verify   CI, before deploying: the Worker has every required secret (no AWS)
 *   bun scripts/secrets.ts ios      writes prod's API_URL and OWNER_TOKEN into Config/Env.xcconfig for device and
 *                                   Release builds
 *   bun scripts/secrets.ts testflight [--export-only]
 *                                   runs scripts/archive with prod's App Store Connect key
 *
 * Every command but `verify` reads env-manager with `env-manager print`, which needs this Mac's AWS access. `ios` reads
 * the process environment instead in GitHub Actions, where the TestFlight workflow passes the repository secrets.
 */
import { spawnSync } from "node:child_process";
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { REQUIRED_IN_PRODUCTION } from "../server/config";
import { readEnv, type Values } from "./lib";

const REPO = "smirea/ShopALotl";
const WORKER_SECRETS = REQUIRED_IN_PRODUCTION;
const CLOUDFLARE_SECRETS = ["CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ACCOUNT_ID"] as const;
const IOS_SETTINGS = ["API_URL", "OWNER_TOKEN"] as const;
/** `scripts/archive` signs the export and uploads to App Store Connect with this key. */
const TESTFLIGHT_SECRETS = ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY_B64"] as const;
const GITHUB_SECRETS = [...CLOUDFLARE_SECRETS, ...TESTFLIGHT_SECRETS, ...IOS_SETTINGS] as const;
const IOS_CONFIG_PATH = new URL("../Config/Env.xcconfig", import.meta.url).pathname;

function require(values: Values, names: readonly string[], env: string): Values {
  const missing = names.filter((name) => !values[name]);
  if (missing.length) throw new Error(`Not set in env-manager ${env}: ${missing.join(", ")}`);
  return Object.fromEntries(names.map((name) => [name, values[name]!]));
}

function run(
  command: string[],
  options: { stdin?: string; env?: Values; inherit?: boolean } = {},
): string {
  const result = spawnSync(command[0]!, command.slice(1), {
    input: options.stdin,
    encoding: "utf8",
    stdio: options.inherit ? "inherit" : ["pipe", "pipe", "inherit"],
    env: { ...process.env, ...options.env },
  });
  if (result.status !== 0) throw new Error(`${command.slice(0, 3).join(" ")} failed`);
  return result.stdout ?? "";
}

/** Wrangler can print a banner before its JSON. */
function workerSecretNames(cloudflare: Values): Set<string> {
  const output = run(["bunx", "wrangler", "secret", "list", "--format", "json"], {
    env: cloudflare,
  });
  return new Set(
    (JSON.parse(output.slice(output.indexOf("["))) as { name: string }[]).map(
      (secret) => secret.name,
    ),
  );
}

function push() {
  const values = readEnv("prod");
  const secrets = require(values, WORKER_SECRETS, "prod");
  run(["bunx", "wrangler", "secret", "bulk"], {
    stdin: JSON.stringify(secrets),
    env: require(values, CLOUDFLARE_SECRETS, "prod"),
  });
  console.log(`Pushed to the Worker: ${Object.keys(secrets).join(", ")}`);
}

function deploy() {
  run(["bunx", "wrangler", "deploy"], {
    env: require(readEnv("prod"), CLOUDFLARE_SECRETS, "prod"),
    inherit: true,
  });
}

function github() {
  const secrets = require(readEnv("prod"), GITHUB_SECRETS, "prod");
  for (const [name, value] of Object.entries(secrets)) {
    run(["gh", "secret", "set", name, "--repo", REPO], { stdin: value });
    console.log(`Set GitHub secret ${name}`);
  }
}

function check() {
  const values = readEnv("prod");
  const onWorker = workerSecretNames(require(values, CLOUDFLARE_SECRETS, "prod"));
  const onGithub = new Set(
    (
      JSON.parse(run(["gh", "secret", "list", "--repo", REPO, "--json", "name"])) as {
        name: string;
      }[]
    ).map((secret) => secret.name),
  );
  const rows = [
    ...WORKER_SECRETS.map((name) => ({
      name,
      where: "Worker",
      ok: Boolean(values[name]) && onWorker.has(name),
    })),
    ...GITHUB_SECRETS.map((name) => ({
      name,
      where: "GitHub",
      ok: Boolean(values[name]) && onGithub.has(name),
    })),
  ];
  for (const row of rows) console.log(`${row.ok ? "ok   " : "DRIFT"} ${row.where} ${row.name}`);
  if (rows.some((row) => !row.ok)) process.exit(1);
}

/** Run by CI before `wrangler deploy`, with the Cloudflare credentials in its environment. */
function verify() {
  const onWorker = workerSecretNames({});
  const missing = WORKER_SECRETS.filter((name) => !onWorker.has(name));
  if (missing.length) {
    console.error(
      `The Worker lacks ${missing.join(", ")}. Set them in env-manager prod, then run bun run secrets:push.`,
    );
    process.exit(1);
  }
  console.log(`The Worker has every required secret: ${WORKER_SECRETS.join(", ")}`);
}

/** The token ships inside the app: the owner's own devices are the only installs, so it is as safe as they are. */
function ios() {
  // Bun loads the schema's development API_URL from `.env` into every local process, so only CI's environment counts.
  const settings = process.env.GITHUB_ACTIONS
    ? require(process.env as Values, IOS_SETTINGS, "the workflow")
    : require(readEnv("prod"), IOS_SETTINGS, "prod");
  // `$()` keeps an xcconfig from reading `//` as the start of a comment.
  const lines = Object.entries(settings).map(
    ([name, value]) => `PRODUCTION_${name} = ${value.replaceAll("//", "/$()/")}`,
  );
  writeFileSync(
    IOS_CONFIG_PATH,
    `// Generated by bun run env:ios from env-manager prod. Do not edit.\n${lines.join("\n")}\n`,
  );
  chmodSync(IOS_CONFIG_PATH, 0o600);
  console.log(`Wrote ${Object.keys(settings).join(", ")} from prod to Config/Env.xcconfig`);
}

/** The key file lives outside the repository, as `scripts/archive` requires, and only for the run. */
function testflight() {
  const { ASC_PRIVATE_KEY_B64, ...key } = require(readEnv("prod"), TESTFLIGHT_SECRETS, "prod");
  const directory = mkdtempSync(join(tmpdir(), "shopalotl-asc-"));
  const path = join(directory, "AuthKey.p8");
  try {
    writeFileSync(path, Buffer.from(ASC_PRIVATE_KEY_B64!, "base64"), { mode: 0o600 });
    run([new URL("./archive", import.meta.url).pathname, ...process.argv.slice(3)], {
      env: { ...key, ASC_KEY_PATH: path },
      inherit: true,
    });
  } finally {
    rmSync(directory, { recursive: true });
  }
}

const commands: Record<string, () => unknown> = {
  push,
  deploy,
  github,
  check,
  verify,
  ios,
  testflight,
};
const command = commands[process.argv[2] ?? ""];
if (!command) {
  console.error(`Usage: bun scripts/secrets.ts <${Object.keys(commands).join("|")}>`);
  process.exit(1);
}
await command();
