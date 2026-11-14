/**
 * Writes the app's copy of the schema from `server/schema.ts`: `bun run generate`. The output is committed, because
 * Xcode and CI build the app without running Bun first. `server/schema.test.ts` fails when it is stale.
 */
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { generate } from 'sync-engine/schema';
import { schema } from '../server/schema';

export const SWIFT_SCHEMA = 'Sources/App/Sync/Generated/SyncSchema.swift';

if (import.meta.main) {
	const swift = join(import.meta.dir, '..', SWIFT_SCHEMA);
	mkdirSync(dirname(swift), { recursive: true });
	generate({ schema, swift });
	console.log(`Wrote ${SWIFT_SCHEMA}`);
}
