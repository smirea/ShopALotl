import type { Space, SqlDriver, Values } from "sync-engine/core";
import { z } from "zod";
import { nameKey } from "./name-key";
import { itemSource, MAIN_LIST_ID, MAX_SOURCES, type ItemSource } from "./schema";

/**
 * How the owner's other apps put things on a list without a sync client of their own: A Better Me adds a recipe's
 * ingredients. They reach the server with the owner token the app shares in the team keychain group
 * (`shopalotl-link`), and the rows they write sync to every device like any other.
 */
export const LISTS_ROUTE = "GET /api/lists";
export const ADD_ITEMS_ROUTE = "POST /api/add-items";
export const SPACE_ROUTES = new Set([LISTS_ROUTE, ADD_ITEMS_ROUTE]);
/** Whether a request the host received with `/api` stripped is one of `SPACE_ROUTES`. */
export const isSpaceRoute = (request: Request) =>
  SPACE_ROUTES.has(`${request.method} /api${new URL(request.url).pathname}`);

/** The first list's name while it has no row (`ShoppingList.main` in the app). */
const MAIN_LIST_NAME = "Groceries";

const name = z.string().trim().min(1).max(200);

const AddItemsRequest = z.object({
  /** An existing list by id, or a new list by name. */
  list: z.union([z.object({ id: z.string().min(1) }), z.object({ name })]),
  source: itemSource,
  items: z
    .array(z.object({ name, quantity: z.string().trim().max(40).default("") }))
    .min(1)
    .max(200),
});
export type AddItemsRequest = z.input<typeof AddItemsRequest>;

export type ListSummary = { id: string; name: string; needed: number };
export type AddItemsResponse = {
  list: { id: string; name: string };
  /** Items that went onto the list: new ones, and remembered ones that were off it or checked. */
  added: number;
  /** Items that were already on the list and still needed, which kept their amount. */
  alreadyNeeded: number;
};

const instant = (date: Date) => date.toISOString();
const json = (status: number, body: unknown) => Response.json(body, { status });

/** Every list in switcher order, with the first list even before it has a row. */
export function readLists(driver: SqlDriver): ListSummary[] {
  const counts = new Map(
    driver
      .exec("SELECT list_id, COUNT(*) AS needed FROM items WHERE state = 'needed' GROUP BY list_id")
      .map((row) => [String(row.list_id), Number(row.needed)]),
  );
  const rows = driver
    .exec("SELECT id, name FROM lists ORDER BY position, created_at, id")
    .map((row) => ({ id: String(row.id), name: String(row.name) }));
  const lists = rows.some((list) => list.id === MAIN_LIST_ID)
    ? rows
    : [{ id: MAIN_LIST_ID, name: MAIN_LIST_NAME }, ...rows];
  return lists.map((list) => ({ ...list, needed: counts.get(list.id) ?? 0 }));
}

const sameSource = (a: ItemSource, b: ItemSource) => a.app === b.app && a.id === b.id;

/**
 * Puts each named item on the list once. Names that share a key are one item, the first name and the first amount
 * winning, so "Onion" from two lines of a recipe is one row. An item already needed keeps its amount, since the owner
 * may have typed one; the source is added to its list. A remembered item comes back as `Edits.added` brings it back:
 * needed, added now, with this amount when one is given.
 */
export function addItems(
  space: Space,
  driver: SqlDriver,
  input: z.output<typeof AddItemsRequest>,
  now: Date,
): AddItemsResponse | null {
  return space.change((server) => {
    let list: { id: string; name: string };
    if ("id" in input.list) {
      const found = readLists(driver).find((list) => "id" in input.list && list.id === input.list.id);
      if (!found) return null;
      list = { id: found.id, name: found.name };
    } else {
      const last = Number(driver.exec("SELECT MAX(position) AS last FROM lists")[0]?.last ?? 0);
      list = { id: crypto.randomUUID().toLowerCase(), name: input.list.name };
      server.put("lists", list.id, {
        name: list.name,
        grouping: "category",
        category_order: "[]",
        position: last + 1,
        created_at: instant(now),
      });
    }

    const wanted = new Map<string, { name: string; quantity: string }>();
    for (const item of input.items) {
      const key = nameKey(item.name);
      if (!key) continue;
      const seen = wanted.get(key);
      if (!seen) wanted.set(key, { ...item });
      else if (!seen.quantity) seen.quantity = item.quantity;
    }

    let added = 0;
    let alreadyNeeded = 0;
    for (const [key, item] of wanted) {
      const id = `${list.id}/${key}`;
      const existing = driver.exec("SELECT state, quantity, sources FROM items WHERE id = ?", [id])[0];
      if (!existing) {
        added++;
        server.put("items", id, {
          list_id: list.id,
          name: item.name,
          state: "needed",
          quantity: item.quantity,
          note: "",
          added_at: instant(now),
          bought: "[]",
          sources: JSON.stringify([input.source]),
        });
        continue;
      }
      const patch: Values = {};
      if (existing.state === "needed") {
        alreadyNeeded++;
        const sources = parseSources(existing.sources);
        if (!sources.some((source) => sameSource(source, input.source)))
          patch.sources = JSON.stringify([...sources, input.source].slice(-MAX_SOURCES));
        if (!existing.quantity && item.quantity) patch.quantity = item.quantity;
      } else {
        added++;
        patch.state = "needed";
        patch.added_at = instant(now);
        patch.sources = JSON.stringify([input.source]);
        if (item.quantity) patch.quantity = item.quantity;
      }
      if (Object.keys(patch).length) server.patch("items", id, patch);
    }
    return { list, added, alreadyNeeded };
  });
}

function parseSources(value: unknown): ItemSource[] {
  const parsed = z.array(itemSource).safeParse(JSON.parse(String(value ?? "[]")));
  return parsed.success ? parsed.data : [];
}

/** Answers `SPACE_ROUTES` after the owner check, with the `/api` prefix stripped. The host nudges live clients when the head moved. */
export async function handleSpaceRoute(
  request: Request,
  space: Space,
  driver: SqlDriver,
  now = new Date(),
): Promise<Response> {
  const route = `${request.method} ${new URL(request.url).pathname}`;
  if (route === "GET /lists") return json(200, { lists: readLists(driver) });
  const body = AddItemsRequest.safeParse(await request.json().catch(() => null));
  if (!body.success)
    return json(400, { ok: false, error: body.error.issues[0]?.message ?? "Invalid body" });
  const result = addItems(space, driver, body.data, now);
  if (!result) return json(404, { ok: false, error: "No such list" });
  return json(200, result);
}
