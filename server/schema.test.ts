import { expect, test } from 'bun:test';
import { mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { generate } from 'sync-engine/schema';
import { SWIFT_SCHEMA } from '../scripts/generate';
import { schema } from './schema';

test('the committed Swift schema matches server/schema.ts', () => {
	const fresh = join(mkdtempSync(join(tmpdir(), 'shopalotl-schema-')), 'SyncSchema.swift');
	generate({ schema, swift: fresh });
	const committed = readFileSync(join(import.meta.dir, '..', SWIFT_SCHEMA), 'utf8');
	expect(committed, 'Run bun run generate and commit the result').toBe(readFileSync(fresh, 'utf8'));
});
