import { expect, test } from "bun:test";
import { bunSqlite } from "sync-engine/bun-sqlite";
import { createSpace } from "sync-engine/core";
import { handleSpaceRoute, type AddItemsRequest } from "./add-items";
import { schema } from "./schema";

const now = new Date("2026-11-27T12:00:00.000Z");
const curry = { app: "a-better-me", id: "r1", title: "Curry" };
const dal = { app: "a-better-me", id: "r2", title: "Dal" };

function setup() {
  const driver = bunSqlite(":memory:");
  const space = createSpace(driver, schema);
  space.migrate();
  const add = async (body: AddItemsRequest) => {
    const request = new Request("http://space/add-items", { method: "POST", body: JSON.stringify(body) });
    const response = await handleSpaceRoute(request, space, driver, now);
    return { status: response.status, body: (await response.json()) as Record<string, unknown> };
  };
  const item = (id: string) => {
    const row = driver.exec("SELECT state, quantity, sources FROM items WHERE id = ?", [id])[0];
    return row && { ...row, sources: JSON.parse(String(row.sources)) };
  };
  return { driver, space, add, item };
}

test("names that share a key are one item, and an item already needed keeps its amount and gains the source", async () => {
  const { add, item, space } = setup();
  space.change((server) =>
    server.put("items", "main/onion", {
      list_id: "main",
      name: "Onion",
      state: "needed",
      quantity: "3",
      added_at: now.toISOString(),
    }),
  );
  const first = await add({
    list: { id: "main" },
    source: curry,
    items: [{ name: "Crème fraîche", quantity: "200 g" }, { name: "creme-fraiche" }, { name: "onion", quantity: "1" }],
  });
  expect(first.body).toMatchObject({ added: 1, alreadyNeeded: 1 });
  expect(item("main/creme fraiche")).toMatchObject({ state: "needed", quantity: "200 g", sources: [curry] });
  expect(item("main/onion")).toMatchObject({ quantity: "3", sources: [curry] });

  await add({ list: { id: "main" }, source: dal, items: [{ name: "Onion" }] });
  await add({ list: { id: "main" }, source: curry, items: [{ name: "Onion" }] });
  expect(item("main/onion")?.sources).toEqual([curry, dal]);
});

test("a remembered item comes back needed with only the source that brought it back", async () => {
  const { add, item, space } = setup();
  space.change((server) =>
    server.put("items", "main/milk", {
      list_id: "main",
      name: "Milk",
      state: "off",
      quantity: "1 l",
      added_at: "2026-11-01T09:00:00.000Z",
      sources: JSON.stringify([dal]),
    }),
  );
  const result = await add({ list: { id: "main" }, source: curry, items: [{ name: "milk" }] });
  expect(result.body).toMatchObject({ added: 1, alreadyNeeded: 0 });
  expect(item("main/milk")).toMatchObject({ state: "needed", quantity: "1 l", sources: [curry] });
});

test("a new list is created by name, and an unknown list id adds nothing", async () => {
  const { add, driver } = setup();
  const created = await add({ list: { name: "Dinner party" }, source: curry, items: [{ name: "Rice" }] });
  const list = created.body.list as { id: string; name: string };
  expect(list.name).toBe("Dinner party");
  expect(driver.exec("SELECT list_id FROM items")).toEqual([{ list_id: list.id }]);

  const missing = await add({ list: { id: "gone" }, source: curry, items: [{ name: "Rice" }] });
  expect(missing.status).toBe(404);
  expect(driver.exec("SELECT COUNT(*) AS n FROM items")[0]?.n).toBe(1);
});
