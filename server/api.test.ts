import { describe, expect, test } from 'bun:test';
import { bunSqlite } from 'sync-engine/bun-sqlite';
import { createSpace, handleSync, type SyncResponse, type Values } from 'sync-engine/core';
import { handle, type App } from './api';
import { DEV_OWNER_TOKEN, parseConfig } from './config';
import { schema } from './schema';

const space = createSpace(bunSqlite(':memory:'), schema);
space.migrate();
const app: App = { config: parseConfig({}), engine: request => handleSync(space, request) };

const sync = (client: string, cursor: number, writes: unknown[], token: string | null = DEV_OWNER_TOKEN) =>
	handle(
		new Request('http://api.test/api/sync', {
			method: 'POST',
			headers: token ? { authorization: `Bearer ${token}` } : {},
			body: JSON.stringify({ protocol: 2, client, cursor, writes }),
		}),
		app,
	);

async function synced(client: string, cursor: number, writes: unknown[]): Promise<SyncResponse> {
	const response = await sync(client, cursor, writes);
	expect(response.status).toBe(200);
	return response.json() as Promise<SyncResponse>;
}

/** The rows of one table in a response, by id. */
const rowsOf = (response: SyncResponse, table: string) =>
	Object.fromEntries(
		response.rows.filter(row => row.table === table).map(row => [row.id, row.deleted ? null : row.values]),
	) as Record<string, Values | null>;

const milk = {
	list_id: 'main',
	name: 'Milk',
	state: 'needed',
	quantity: '2',
	note: '',
	added_at: '2026-11-14T09:00:00.000Z',
	bought: '[]',
};

describe('handle', () => {
	test('everything under /api needs the owner token, and /status does not', async () => {
		expect((await handle(new Request('http://api.test/status'), app)).status).toBe(200);
		expect((await sync('a', 0, [], null)).status).toBe(401);
		expect((await sync('a', 0, [], 'wrong')).status).toBe(401);
		const live = new Request('http://api.test/api/live', { headers: { upgrade: 'websocket' } });
		expect((await handle(live, app)).status).toBe(401);
		const feedback = new Request('http://api.test/api/feedback', { method: 'POST', body: 'x' });
		expect((await handle(feedback, app)).status).toBe(401);
	});

	test('an item put by one device reaches another as a full row, and a check is one patch', async () => {
		const pushed = await synced('a', 0, [{ seq: 1, table: 'items', id: 'main/milk', op: 'put', values: milk }]);
		expect(pushed.acked).toBe(1);
		expect(pushed.rejected).toEqual([]);

		const pulled = await synced('b', 0, []);
		expect(rowsOf(pulled, 'items')).toEqual({ 'main/milk': { id: 'main/milk', ...milk } });

		const bought = '["2026-11-15T10:00:00.000Z"]';
		await synced('b', pulled.head, [
			{ seq: 1, table: 'items', id: 'main/milk', op: 'patch', values: { state: 'checked', bought } },
		]);
		const after = await synced('a', pushed.head, []);
		expect(rowsOf(after, 'items')).toEqual({ 'main/milk': { id: 'main/milk', ...milk, state: 'checked', bought } });
	});

	test('a write a validator refuses is rejected alone', async () => {
		const response = await synced('e', 0, [
			{ seq: 1, table: 'items', id: 'main/x', op: 'put', values: { ...milk, state: 'bought' } },
			{ seq: 2, table: 'items', id: 'main/eggs', op: 'put', values: { ...milk, name: 'Eggs' } },
		]);
		expect(response.rejected.map(write => write.id)).toEqual(['main/x']);
		expect(response.acked).toBe(2);
	});
});
