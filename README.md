<p align="center"><img src="docs/assets/icon.svg" alt="The ShopALotl mascot, an orange axolotl checking a shopping list" width="140"></p>

# ShopALotl

An offline-first shopping list for iOS and macOS, built for one owner. Adding, checking, editing, and removing an item each take one gesture, and nothing waits on the network.

- **Add fast.** Type in the bar at the bottom. `2 milk, eggs x12, tahini (the good one)` adds three items with their amounts and a note. Matches from what you bought before and from a built-in grocery catalog appear as you type, best match nearest your thumb.
- **Sorted by aisle.** A new item files itself under its aisle. The catalog knows common groceries, the on-device model (Apple Intelligence) files the rest, and a correction you make sticks for that name on every list.
- **It learns your staples.** Items you buy on a rhythm show up as one-tap chips above the add bar when they are due.
- **Several lists.** A shopping list sorts by aisle in the order you set for that store. A plain list, such as a packing list, keeps the order you add things in.
- **Synced.** Your data lives in a SQLite file on the device and syncs through one Cloudflare Worker at `https://shopalotl.stf.lol`.

## Run it

Requires Xcode 27 and Bun.

```sh
bun install
./scripts/run -t simulator   # builds, launches, and starts the local sync server
./scripts/run                # on a connected iPhone, synced with production
```

A device build needs this Mac's env-manager access for production's address and token. `./scripts/run --targets` lists devices and simulators.

## Test it

```sh
swift test        # the app's logic, on macOS
bun run test      # the server
bun run typecheck
```

## Where things are

| Path | What it holds |
| --- | --- |
| `Sources/App` | The SwiftUI app: `Logic` (pure rules), `Store` (writes and the list model), `Screens`, `Sync` |
| `server` | The Worker, the local server, and `schema.ts`, the tables for both sides |
| `scripts` | `run` (launcher), `icons` (renders the icon from `docs/assets/icon.svg`), `secrets.ts` (env-manager to Cloudflare and GitHub) |

`AGENTS.md` covers the app's rules, sync, the environment, simulators, Feedback, and ProcrastiMate. Shake the phone to send feedback as an image, a GitHub issue, or a task in ProcrastiMate's `ShopALotl` project.
