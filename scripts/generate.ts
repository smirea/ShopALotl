/**
 * Writes the app's copy of the schema from `server/schema.ts`: `bun run generate`. The output is committed, because
 * Xcode and CI build the app without running Bun first. `bun run schema:check` fails when it is stale.
 */
import { mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { generate } from "sync-engine/schema";
import { schema } from "../server/schema";

const SWIFT_SCHEMA = "Sources/App/Sync/Generated/SyncSchema.swift";
const committed = join(import.meta.dir, "..", SWIFT_SCHEMA);

if (Bun.argv.includes("--check")) {
  const directory = mkdtempSync(join(tmpdir(), "shopalotl-schema-"));
  const fresh = join(directory, "SyncSchema.swift");
  generate({ schema, swift: fresh });
  const stale = readFileSync(fresh, "utf8") !== readFileSync(committed, "utf8");
  rmSync(directory, { recursive: true });
  if (stale) {
    console.error(`${SWIFT_SCHEMA} is stale. Run bun run generate and commit the result.`);
    process.exit(1);
  }
} else {
  mkdirSync(dirname(committed), { recursive: true });
  generate({ schema, swift: committed });
  console.log(`Wrote ${SWIFT_SCHEMA}`);
}
