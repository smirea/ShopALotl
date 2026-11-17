---
project: ShopALotl
gc: agent-t3-worktree gc --repo .
teardown: agent-t3-worktree teardown
ship: pr-ship --merge
---

Repo config for the global `task-orchestrator` skill (`~/code/ai-files/skills/task-orchestrator/`). Its `scripts/check-config.ts` validates this file.

# Orchestrator

- `AGENTS.md` holds the app's rules and decisions. There are no separate decision docs.
- Most tasks arrive from the app's Feedback editor (Share › ProcrastiMate) with an annotated image and `feedback.json`, which names each component's source file and line. `procrastimate images` downloads both.
- Natural areas: the list screen (`Sources/App/Screens`), the rules (`Sources/App/Logic`), the store (`Sources/App/Store`), sync (`Sources/App/Sync`), and the server (`server/`). The app is one screen, so every task that changes how that screen looks or behaves goes in one job.
- Clients a job can cover: iPhone, Mac, server.
- Usual shared work: a change to `server/schema.ts`, a new rule in `Sources/App/Logic` that several tasks rely on. Schema changes are additive, so schema jobs don't wait on each other: the one that merges second reruns `bun run generate`.
- Human-only tasks: a check on a physical iPhone.
- Known shared failures: a simulator runtime that stopped booting.

# Worker

## Setup

- `AGENTS.md` is the whole rulebook: read it before anything else.
- Your worktree builds from the schema defaults (`env-manager gen --local`) and syncs with its own local server over `.data/<checkout>.sqlite`, on its own ports from `.env.override`. Nothing is shared with the main checkout.

## Verification: boot a simulator only to look at the app

The Mac runs many jobs at once, and each booted simulator slows all of them. Climb this ladder and stop at the first rung that proves the change, but a change to what the owner sees or taps always reaches rung 3, and you tap it.

1. Rules and writes: `swift test` (seconds, on macOS, no simulator). Server: `bun run test`, `bun run typecheck` and `bun run lint:ci`. The pre-commit hook runs these, and `swift test` when a Swift file is staged.
2. Does the app compile for iOS: `xcodebuild build -project App.xcodeproj -scheme App -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -derivedDataPath DerivedData/simulator -clonedSourcePackagesDirPath DerivedData/SourcePackages` (no boot). Skip it when rung 3 runs next. Use it after every rebase, and as the check for a Swift conflict when `pr-ship` exits 2.
3. UI behavior: `./scripts/run -t "$(agent-simulator udid)" --headless --no-watch`, then T3's device tools as `AGENTS.md` describes. If it exits 3, the Mac was busy: rerun it. Finish the logic and server side first and batch every check into one session, so the simulator boots once, late.

- Shut it down as soon as you have what you need: `agent-device close`, `device_close` with `shutdown: true`, then `./scripts/run --stop`, which stops the server rung 3 started.
- Count the taps. The product's goals are simplicity, efficiency, and performance, so a change that adds a step to adding, checking, editing, or removing an item needs a reason in the PR.
- Device-only checks: a simulator can't prove speed on the phone. Prove the logic with tests and name the device check in `verification`.
- Upgrade check for entitlements, `Info.plist`, signing, or the stored schema: install master's build on your simulator (from a throwaway `git worktree add`), then yours over it, and launch with the existing data.

## PR

- After changing `server/schema.ts`, run `bun run generate` and commit `Sources/App/Sync/Generated/SyncSchema.swift`. Two schema PRs conflict in that file: the one that merges second takes master's copy, rebases, and reruns `bun run generate`. Never hand-merge it.

## After the merge

- A push to `master` deploys the Worker after CI passes, so a server change is live once master's CI run for your merge is green.
- A Worker secret goes on the Worker with `bun run secrets:push` after its `env-manager up`. If master's deploy already failed on `secrets verify`, `gh run rerun --failed <run>`, and report `merged` only once it succeeds.
