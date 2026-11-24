import { $ } from "bun";
import { appendFileSync } from "node:fs";
import { extname } from "node:path";
import { env } from "node:process";

const { BASE_SHA: base, HEAD_SHA: head, EVENT_NAME: event, GITHUB_OUTPUT: output } = env;
if (!head || !event || !output) throw new Error("Missing change detection environment");

// A force-push leaves `before` pointing at a commit the new history lacks.
const missingBase =
  !base ||
  /^0+$/.test(base) ||
  (await $`git cat-file -e ${base}^{commit}`.nothrow().quiet()).exitCode !== 0;
const full = event === "workflow_dispatch" || missingBase;
const comparison = event === "pull_request" ? `${base}...${head}` : `${base}..${head}`;
const paths = (
  full ? [] : (await $`git diff --name-only -z ${comparison}`.text()).split("\0")
).filter(
  (name) =>
    name && ![".md", ".rst"].includes(extname(name).toLowerCase()) && !name.startsWith("docs/"),
);
// `server/schema.ts` changes the committed Swift schema, which `lint:ci` checks, so the server alone skips Swift.
const swift =
  full || paths.some((name) => !name.startsWith("server/") && name !== "wrangler.jsonc");

appendFileSync(output, `swift=${swift}\n`);
