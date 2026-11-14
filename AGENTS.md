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

# Sync and server

- The app is offline first. Every screen reads and writes the device's SQLite file through `LocalStore` (`Sources/App/Sync`). The engine's triggers queue each write, and `SyncClient` sends it to `POST /api/sync` and pulls what changed. Nothing waits on the network.
- One owner, no accounts. One secret, `OWNER_TOKEN`, is the bearer on every request. All data lives in one space, the Durable Object named `owner`.
- `server/schema.ts` defines the tables for both sides. After changing it, run `bun run generate` and commit `Sources/App/Sync/Generated/SyncSchema.swift`; `server/schema.test.ts` fails when it is stale. Schema changes are additive: a new column needs a default or must be nullable, and a column is never renamed or removed.
- Rows are keyed by what they describe (`<listId>/<nameKey>` for an item), so two devices that add the same thing offline write one row. `NameKey`'s rules are frozen, and `Tests/AppTests/NameKeyTests.swift` pins them.
- `server/api.ts` is the one fetch handler. `server/worker.ts` serves it on Cloudflare and `server/dev.ts` with Bun over `.data/<checkout>.sqlite`. `GET /status` is open, and everything under `/api` needs the owner token.
- `./scripts/run` starts the local server for a simulator or Mac run when it is not running. `./scripts/run --stop` stops it. `bun run start:server` runs it in the foreground.
- A simulator or Mac Debug build syncs with the local server. A device build and every Release build sync with production, `https://shopalotl.stf.lol` (`Config/Base.xcconfig`). They need `Config/Env.xcconfig`, which `bun run env:ios` writes from env-manager `prod` and `./scripts/run` writes for a device when it is missing.
- `bun run test` runs the server tests, `swift test` the app's logic tests on macOS, and `bun run typecheck` the TypeScript.
- A push to `master` deploys the Worker after CI passes. `bun scripts/secrets.ts deploy` deploys from this Mac.

# Environment

- The root `.env` is the env-manager schema of project `shopalotl`, with environments `dev` and `prod` in AWS. `env-manager gen --local` writes `Config/LocalSecrets.xcconfig` and `server/.env.local` from the schema defaults, which is all a worktree or CI needs.
- Use the global `env-manager` for `env set`, `down`, and `up`; it has the AWS credentials. After adding a setting, set its value in each environment and run `env-manager up`, then `bun run secrets:push` for a Worker secret.
- `scripts/secrets.ts` is the one bridge from env-manager to the Worker, GitHub, and the app's production build settings. It never prints a value.
- Secrets are optional in the schema, so offline generation works. `server/config.ts` lists what production requires in `REQUIRED_IN_PRODUCTION` and refuses to start without it.

# Feedback

- `Feedback.enable()` in `Sources/App/App.swift` turns on shake-to-feedback from `https://github.com/smirea/feedback-engine`. In a simulator, shake with `xcrun simctl notify_post <udid> com.apple.UIKit.SimulatorShake`, then press `Add Feedback` within 5 seconds.
- When you build or change a SwiftUI screen, row, card, or chart, follow Feedback's accessibility skill. Read the latest with `gh api repos/smirea/feedback-engine/contents/skills/feedback-accessibility/SKILL.md -H 'Accept: application/vnd.github.raw'`.
- The editor's **GitHub Issue** entry posts to `POST /api/feedback` (`server/feedback.ts`), which files an issue in `smirea/ShopALotl` as the `smirea-ai` account, labeled `feedback`. The server needs `GITHUB_TOKEN`, that account's `gh auth token`.
- Feedback needs UIKit. On macOS, `Sources/App/Support/FeedbackShim.swift` compiles its tags to nothing, so views stay shared.
- The **ProcrastiMate** entry in the editor's Share menu comes from the `com.stefan.shared` keychain group in `Config/App.entitlements`. The simulator build is signed ad hoc so the group counts.

# README

- `README.md` starts as the scaffold's placeholder. Once the project takes shape, rewrite it for this project and keep it short.
