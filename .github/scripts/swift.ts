import { $ } from "bun";
import { env } from "node:process";

const directory = env.SWIFT_DIRECTORY;
if (!directory) throw new Error("Missing SWIFT_DIRECTORY");

await $`bun scripts/own-packages.ts .build/SourcePackages`.cwd(directory);

switch (Bun.argv[2]) {
  case "package":
    // `swift test` compiles every target, the app's included, so it is the macOS compile check too.
    await $`swift test`.cwd(directory);
    break;
  case "app":
    await $`xcodebuild build -project App.xcodeproj -scheme App -derivedDataPath DerivedData/ci -clonedSourcePackagesDirPath .build/SourcePackages CODE_SIGNING_ALLOWED=NO -configuration Release -destination ${"generic/platform=iOS Simulator"}`.cwd(
      directory,
    );
    break;
  default:
    throw new Error(`Unknown Swift task: ${Bun.argv[2]}`);
}
