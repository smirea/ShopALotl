# Stack

- App: Swift and SwiftUI, Swift Package Manager, minimum iOS 27 and macOS 27, in `Sources/App`
- Server: one Cloudflare Worker with one SQLite Durable Object, TypeScript on Bun, in `server/`
- Sync: `https://github.com/smirea/sync-engine`. Its `docs/protocol.md` is the contract.
- Keep dependencies rare and intentional

# Development

- Run `./scripts/run` to build, install, and launch the app, with automatic rebuild and relaunch after saving. Requires Bun and Xcode. Stop with Ctrl-C, or use `--no-watch` for one launch.
- Use `./scripts/run --targets` to list devices and simulators; `*` marks the effective default. Select with `-t simulator`, `-t mac`, or `-t "iPhone 17"` (also accepts an identifier). It opens Device Hub on Xcode 27 or Simulator.app on earlier Xcode versions.
- Selection precedence is `-t` / `--target`, then `SWIFT_RUN_DEFAULT_TARGET`, then a connected iOS device, booted simulator, available simulator, or My Mac. Duplicate simulator names prefer a booted instance, then the newest runtime; use an identifier to select exactly. Add simulator runtimes in Xcode's settings.
- Agents run simulators headless: `./scripts/run -t "$(agent-simulator udid)" --headless` builds, installs, and launches without opening Simulator.app or Device Hub, booting the simulator while the app builds. `agent-simulator udid` creates and claims the worktree's own simulator, named after the worktree directory (`udid 2` for a second one). Never pick or create one with `xcrun simctl create`.
- When the launcher targets a simulator it runs `agent-simulator claim`, and before a headless boot `agent-simulator wait`, which holds the boot while the Mac is busy. Exit code 3 means rerun the same command. Both are skipped where `~/bin/agent-simulator` is missing, as in CI.
- Drive the simulator only with the command T3 Code's `device_open` returns, tapping by label (`press 'label="Save"' --settle`), and look at it with `device_screenshot`. Never write a wrapper around `simctl` or `idb` for taps or screenshots.
- Settling the thread, or merging its PR, stops and deletes the worktree's simulators. `agent-simulator stop` shuts them down earlier.
- `--pair-watch` pairs the simulator with a watch (the newest model on the newest watchOS, reusing an existing pair), boots both while the app builds, and installs and launches an embedded watch app. `./scripts/run -t <udid> --delete` (a udid only, never a name) shuts down and deletes the simulator and its paired watches; `simctl delete` of the phone alone leaves the watch behind.
- `./scripts/run` grants every `simctl privacy` service on a first install, so simulators start on the default, granted path. It skips later installs because the grant also resets HealthKit access. To test a denied state, run `xcrun simctl privacy <udid> revoke <service> <bundle id>` first. HealthKit has no `simctl` service.
- Physical devices need Xcode pairing, Developer Mode, and an unlocked screen. Configure automatic signing in Xcode, pass `--team`, or set `SWIFT_RUN_DEVELOPMENT_TEAM`.
- The mascot, `docs/assets/icon.svg`, is the source of the app icon, the launch image, and the in-app `Mascot` image. After changing it, or the backdrop colors in `scripts/icons`, run `./scripts/icons` and commit the files it writes under `Sources/App/Assets.xcassets`.
- Edit SwiftUI code and resources in `Sources/App`; Xcode picks up new files automatically. Open `App.xcodeproj` and use the shared `App` scheme for debugging.
- Build errors leave the watcher running; fix the error and save again. Build output is in `DerivedData/device/build.log`, `DerivedData/simulator/build.log`, or `DerivedData/mac/build.log`.
- `swift build` checks the shared code on macOS. Use the Xcode project for simulator builds and bundled resources; `swift run` launches the macOS executable.

# App

- The app is one screen, `Sources/App/Screens/ListScreen.swift`: a list, an add bar pinned to the bottom, and the list switcher behind the title. Simplicity, efficiency, and performance are the product's goals, so count taps before adding a step to adding, checking, editing, or removing an item.
- `Sources/App/Logic` holds the rules as pure functions over values, with tests in `Tests/AppTests`: `EntryParser` (typed text to entries), `Edits` (what each gesture does to a row), `Categorizer` and `Catalog` (which aisle a name belongs to), `Suggestions` and `Habit` (what to offer), and `Layout` (rows into sections). Put new behavior there first and test it there.
- `Sources/App/Store` writes: `ItemActions` and `ListActions` are the only code that changes rows, and every item change goes through `apply`, which records it for undo. The list offers Undo after a gesture that takes a row away: a removal, a clear, a rename. `ListModel` is one open list: a gesture writes, re-reads, and redraws in the same turn, with no optimistic copy.
- Adding keeps the list in sight: the suggestion panel sits above the add bar at most 40% of the screen tall, a tap on the list closes the keyboard, and an added row animates in and scrolls into view. There is no Done button and no hint text. Keep visible copy to labels; explanations belong nowhere on this screen.
- A checked row stays in its aisle, struck through. The eye at the top right hides or shows checked rows on every list of the device, and Clear at the top left takes them off the list. Two controls on one side push the title off center, so keep one per side.
- Rows hold still. A row keeps the section it was drawn in until 1.5 seconds after the last touch (`ListModel.settleDelay`), so a late category answer waits and a row checked while checked rows are hidden stays in sight. A gesture moves only the rows it wrote, through `reload(releasing:)`. Do not move a row under the finger.
- An item has no category. `Categorizer.place` reads the owner's answer, then the catalog's entry for the whole name, then the on-device model's stored answer, then a guess from part of the name. `CategoryInference` asks the model (FoundationModels) only about guesses and stores its answer in `item_categories` as source `model`. The owner's answer has its own row, so nothing overwrites it.
- An item row is the list entry, the autocomplete entry, and the purchase history at once. Taking an item off the list sets `state = 'off'`. Suggestions and the due rail come from each row's `bought` instants.
- Performance: the hot paths (a keystroke in the add field, an add, a check) do no async work before the screen updates.

# Sync and server

- The app is offline first. Every screen reads and writes the device's SQLite file through `LocalStore` (`Sources/App/Sync`). The engine's triggers queue each write, and `SyncClient` sends it to `POST /api/sync` and pulls what changed. Nothing waits on the network.
- One owner, no accounts. One secret, `OWNER_TOKEN`, is the bearer on every request. All data lives in one space, the Durable Object named `owner`.
- `server/schema.ts` defines the tables for both sides. After changing it, run `bun run generate` and commit `Sources/App/Sync/Generated/SyncSchema.swift`; `bun run schema:check` fails when it is stale. Schema changes are additive: a new column needs a default or must be nullable, and a column is never renamed or removed.
- A write names only the columns it changed, so two devices that change different fields of a row both keep their change. The item editor passes only the fields the owner touched. A row's first write is the exception: it syncs whole, so two devices that each make the first change to the first list offline keep only the later one.
- Timestamps are text with whole milliseconds. `Instant.text` rounds, so a row reads and writes back unchanged.
- Rows are keyed by what they describe (`<listId>/<nameKey>` for an item), so two devices that add the same thing offline write one row. `NameKey`'s rules are frozen, and `Tests/AppTests/NameKeyTests.swift` pins them.
- `server/api.ts` is the one fetch handler. `server/worker.ts` serves it on Cloudflare and `server/dev.ts` with Bun over `.data/<checkout>.sqlite`. `GET /status` is open, and everything under `/api` needs the owner token.
- `./scripts/run` starts the local server for a simulator or Mac run when it is not running. `./scripts/run --stop` stops it. `bun run start:server` runs it in the foreground. Another project's server on `API_PORT` fails the run, since `GET /status` names the service.
- A simulator or Mac Debug build syncs with the local server. A device build and every Release build sync with production, `https://shopalotl.stf.lol` (`Config/Base.xcconfig`). They need `Config/Env.xcconfig`, which `bun run env:ios` writes from env-manager `prod` and `./scripts/run` writes for a device when it is missing.
- A push to `master` deploys the Worker after CI passes. `bun scripts/secrets.ts deploy` deploys from this Mac.

# Checks

- `swift test` runs the app's logic tests on macOS, `bun run test` the server tests, and `bun run typecheck` the TypeScript. `bun run lint` fixes lint and formatting with oxlint and oxfmt and regenerates the Swift schema; `bun run lint:ci` only checks, the schema included.
- The pre-commit hook, `lefthook.yml`, is installed by `bun install`. It runs in parallel: the fixers on the staged files, and, when a file of their kind is staged, the type check, the schema check, the server tests, and `swift test`. It takes about a second warm; the first `swift test` in a new worktree also compiles the package.
- CI runs `lint:ci`, `typecheck`, `test` and `build` as their own jobs on every change, and `swift test` and the iOS app build on a macOS runner when native files changed. `.github/CI.md` has the details.
- Read the `tests` skill before adding, changing or fixing a test.

# Environment

- The root `.env` is the env-manager schema of project `shopalotl`, with environments `dev` and `prod` in AWS. `env-manager gen --local` writes `Config/LocalSecrets.xcconfig` and `server/.env.local` from the schema defaults, which is all a worktree or CI needs.
- Use the global `env-manager` for `env set`, `down`, and `up`; it has the AWS credentials. After adding a setting, set its value in each environment and run `env-manager up`, then `bun run secrets:push` for a Worker secret.
- `scripts/secrets.ts` is the one bridge from env-manager to the Worker, GitHub, and the app's production build settings. It never prints a value.
- Secrets are optional in the schema, so offline generation works. `server/config.ts` lists what production requires in `REQUIRED_IN_PRODUCTION` and refuses to start without it.

# TestFlight

- `.github/workflows/testflight.yml` uploads a build on every push to `master` that touches the app (`Sources`, `Config`, `App.xcodeproj`, `scripts/archive`, `scripts/secrets.ts`). It waits ten minutes so a burst of pushes uploads once, and a manual dispatch (`gh workflow run testflight.yml`) builds right away. The internal group `me` has every build, so the build shows in the TestFlight app once App Store Connect has processed it.
- `scripts/archive` archives Release unsigned, signs the app ad hoc with `Config/App.entitlements`, and lets the export sign it for distribution with the App Store Connect key. `bun run testflight` runs it on this Mac with the key from env-manager `prod`, and `bun run testflight --export-only` stops at `DerivedData/archive/export/App.ipa`.
- The build number is the upload's UTC time as `year.MMdd.HHmmss`. Raise `MARKETING_VERSION` in `Config/Base.xcconfig` only for a new version; the app and the widget share it, as App Store Connect requires.
- The key (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY_B64`) and the app's production `API_URL` and `OWNER_TOKEN` reach the workflow as repository secrets through `bun run secrets:github`. Run it after changing any of them in env-manager `prod`.
- App Store Connect refuses an upload that calls a required-reason API missing from `Sources/App/PrivacyInfo.xcprivacy`. The app's one is `UserDefaults`. Add the entry in the same change as the first call to another (file timestamps, disk space, boot time).

# Widget

- `Sources/Widget` is a WidgetKit extension (iOS only) in small, medium and large sizes: the open list's items one per row, in the app's order without aisle headers, following the eye's setting. A tap on a row checks it through `CheckItemIntent`; small and medium carry an open-app button over the last row.
- The app and the widget share the App Group `group.com.stefan.shopalotl`: the SQLite file (`LocalDatabase.url`) and the open list and eye settings (`AppGroup.defaults`). An install from before the widget moves its file there on first launch (`LocalDatabase.adopt`). The widget never creates the file.
- The widget compiles the app's model, logic and sync files listed in the `Widget` exception set of `App.xcodeproj`. Code it shares stays free of SwiftUI screens and `LocalStore`; `ItemWrites` and `ListReads` work on a bare `Database`.
- A widget check writes, posts `AppGroup.changedNotification`, and sends its own sync without waiting for it. The app re-reads every observed query when it becomes active or hears the notification (`LocalStore.refreshFromOtherProcesses`), and reloads the widget after any change to its rows.
- Each row's intent carries the state a tap leads to, and the row is a `Toggle`, so WidgetKit flips it the moment it is tapped. Do not use `SetValueIntent`: the system sent its value as nil.
- An App Store Connect API key cannot create or assign App Groups (`/appGroups` answers 401), so a new group or a new target in one is a one-time step in the developer portal.

# Feedback

- `Feedback.enable()` in `Sources/App/App.swift` turns on shake-to-feedback from `https://github.com/smirea/feedback-engine`. In a simulator, shake with `xcrun simctl notify_post <udid> com.apple.UIKit.SimulatorShake`, then press `Add Feedback` within 5 seconds.
- When you build or change a SwiftUI screen, row, card, or chart, follow Feedback's accessibility skill. Read the latest with `gh api repos/smirea/feedback-engine/contents/skills/feedback-accessibility/SKILL.md -H 'Accept: application/vnd.github.raw'`.
- The editor's **GitHub Issue** entry posts to `POST /api/feedback` (`server/feedback.ts`), which files an issue in `smirea/ShopALotl` as the `smirea-ai` account, labeled `feedback`. The server needs `GITHUB_TOKEN`, that account's `gh auth token`.
- Feedback needs UIKit. On macOS, `Sources/App/Support/FeedbackShim.swift` compiles its tags to nothing, so views stay shared.

# ProcrastiMate

- The repo's tasks live in the ProcrastiMate project `ShopALotl`. `procrastimate tasks ShopALotl` lists them.
- The **ProcrastiMate** entry in the Feedback editor's Share menu posts the feedback as a task with the annotated image and `feedback.json` attached. It comes from the `com.stefan.shared` keychain group in `Config/App.entitlements`, where ProcrastiMate keeps its session while it is signed in on the same device. The simulator build is signed ad hoc so the group counts. Without ProcrastiMate signed in, the sheet says so.
- `/task-orchestrator` works the project's tasks through `.agents/task-orchestrator.md`. After changing that file, run `~/code/ai-files/skills/task-orchestrator/scripts/check-config.ts`.

# README

- `README.md` starts as the scaffold's placeholder. Once the project takes shape, rewrite it for this project and keep it short.
