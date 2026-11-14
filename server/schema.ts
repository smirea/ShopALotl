import { real, sqliteTable, text } from 'drizzle-orm/sqlite-core';
import { defineSchema } from 'sync-engine/core';
import { z } from 'zod';

/**
 * The synced tables. Two rules shape them:
 *
 * 1. A row is keyed by what it describes. An item is `<listId>/<nameKey>`, a category answer is `<nameKey>#<source>`,
 *    the first list is `main`. Two offline devices that add "Milk" to one list write the same row.
 * 2. Built-ins are not rows. The first list, the categories, and the grocery catalog live in the app. A `lists` row
 *    with the id `main` exists only once the owner changed that list, so a fresh device never puts defaults over
 *    another device's edits. Nothing is seeded.
 *
 * Item rows are rarely deleted: taking an item off a list is `state = 'off'`, which keeps its purchase history for
 * suggestions and makes undo a patch back. The name key is `NameKey` in the app. Its rules are frozen, because
 * changing them would orphan every id made before; `Tests/AppTests/NameKeyTests.swift` pins them.
 */

const json = (name: string) => text(name, { mode: 'json' });

/** The list every install has without a row. */
export const MAIN_LIST_ID = 'main';
/** `category` shows aisle headers and infers categories; `none` is a plain list (packing, todo) in added order. */
export const LIST_GROUPINGS = ['category', 'none'] as const;
/** `needed` and `checked` are on the list; `off` is remembered for suggestions only. */
export const ITEM_STATES = ['needed', 'checked', 'off'] as const;
export const CATEGORY_SOURCES = ['user', 'model'] as const;
/** How many purchase instants an item keeps. Enough for a median interval, small enough to rewrite whole. */
export const MAX_BOUGHT = 12;

export const lists = sqliteTable('lists', {
	/** `main`, or a lowercase UUID. */
	id: text('id').primaryKey(),
	name: text('name').notNull(),
	grouping: text('grouping', { enum: LIST_GROUPINGS }).notNull().default('category'),
	/**
	 * `[categoryId]`, this list's aisle order, rewritten whole on a reorder. Per list because aisle order is a fact
	 * about a store. The reader appends every category the array does not name in built-in order, so `[]` is the
	 * built-in order.
	 */
	categoryOrder: json('category_order').notNull().default([]),
	/** Order in the list switcher. Fractional, so moving a list patches one row. */
	position: real('position').notNull().default(0),
	createdAt: text('created_at').notNull(),
});

/**
 * One thing on one list, for as long as the list remembers it. The list entry, the autocomplete entry, and the
 * purchase history of "milk on Groceries" are one row, so "is it already on the list" is a key lookup. Renaming an
 * item moves it to the row of its new key.
 *
 * An item has no category column. A category is a fact about the name (`item_categories`), read at display time, so
 * fixing it once fixes it on every list and in every suggestion.
 */
export const items = sqliteTable('items', {
	id: text('id').primaryKey(),
	/** The id's prefix, written once. A column so a list reads its rows without parsing ids. */
	listId: text('list_id').notNull(),
	/** As last typed. The key in the id is derived from it. */
	name: text('name').notNull(),
	/** One column, so check, uncheck, clear, remove, re-add, and every undo are each one patch that cannot tear. */
	state: text('state', { enum: ITEM_STATES }).notNull().default('needed'),
	/** Display text: `''`, `'2'`, `'500 g'`. Stays when the item goes `off`: it is the usual amount next time. */
	quantity: text('quantity').notNull().default(''),
	note: text('note').notNull().default(''),
	/** When it last went onto the list. Orders a plain list. */
	addedAt: text('added_at').notNull(),
	/**
	 * `[instant]`, ascending, at most `MAX_BOUGHT`: when it was checked off. One column, rewritten whole, so the
	 * count, the last purchase, and the interval between purchases cannot disagree after a merge.
	 */
	bought: json('bought').notNull().default([]),
});

/**
 * What category a name belongs to, one row per source. The owner and the on-device model each write their own row,
 * because a first write is a put of the whole row: sharing one row would let a stale device's model answer erase the
 * owner's correction. The reader takes the owner's answer, then the app's catalog, then the model's.
 */
export const itemCategories = sqliteTable('item_categories', {
	/** `<nameKey>#user` or `<nameKey>#model`. */
	id: text('id').primaryKey(),
	nameKey: text('name_key').notNull(),
	source: text('source', { enum: CATEGORY_SOURCES }).notNull(),
	/** A category id the app knows. One it does not know reads as no answer. */
	category: text('category').notNull(),
});

/** The order here is the order of the generated Swift schema and of a snapshot pull. */
const SYNCED_TABLES = { lists, items, item_categories: itemCategories } as const;

const name = z.string().trim().min(1).max(200);
const instant = z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
/** Not an enum: a newer app can add a category without a deploy. */
const categoryId = z.string().min(1).max(64);

/**
 * Per-column checks. The engine validates columns, never the id, and has no cross-row constraints, so the app builds
 * an item's id and `listId` from one value and hides items whose list is gone.
 */
export const schema = defineSchema({
	tables: SYNCED_TABLES,
	values: {
		lists: {
			name,
			grouping: z.enum(LIST_GROUPINGS),
			categoryOrder: z.array(categoryId),
			position: z.number().finite(),
			createdAt: instant,
		},
		items: {
			listId: z.string().min(1),
			name,
			state: z.enum(ITEM_STATES),
			quantity: z.string().max(40),
			note: z.string().max(500),
			addedAt: instant,
			bought: z.array(instant).max(MAX_BOUGHT),
		},
		item_categories: { nameKey: z.string().min(1).max(200), source: z.enum(CATEGORY_SOURCES), category: categoryId },
	},
});
