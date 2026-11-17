import { $ } from 'bun';
import { env } from 'node:process';

const directory = env.SWIFT_DIRECTORY;
if (!directory) throw new Error('Missing SWIFT_DIRECTORY');

const xcodeArgs = [
	'-project',
	'App.xcodeproj',
	'-scheme',
	'App',
	'-derivedDataPath',
	'DerivedData/ci',
	'-clonedSourcePackagesDirPath',
	'.build/SourcePackages',
	'CODE_SIGNING_ALLOWED=NO',
];

switch (Bun.argv[2]) {
	case 'checks':
		await $`swift build`.cwd(directory);
		break;
	case 'tests':
		await $`swift test`.cwd(directory);
		break;
	case 'build':
		await $`xcodebuild build ${xcodeArgs} -configuration Release -destination ${'generic/platform=iOS Simulator'}`.cwd(
			directory,
		);
		break;
	default:
		throw new Error(`Unknown Swift task: ${Bun.argv[2]}`);
}
