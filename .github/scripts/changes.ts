import { $ } from 'bun';
import { appendFileSync } from 'node:fs';
import { extname } from 'node:path';
import { env } from 'node:process';

const { BASE_SHA: base, HEAD_SHA: head, EVENT_NAME: event, GITHUB_OUTPUT: output } = env;
if (!head || !event || !output) throw new Error('Missing change detection environment');

// A force-push leaves `before` pointing at a commit the new history lacks.
const missingBase =
	!base || /^0+$/.test(base) || (await $`git cat-file -e ${base}^{commit}`.nothrow().quiet()).exitCode !== 0;
const full = event === 'workflow_dispatch' || missingBase;
const comparison = event === 'pull_request' ? `${base}...${head}` : `${base}..${head}`;
const paths = (full ? [] : (await $`git diff --name-only -z ${comparison}`.text()).split('\0')).filter(
	name => name && !['.md', '.rst'].includes(extname(name).toLowerCase()) && !name.startsWith('docs/'),
);
const common = full || paths.some(name => name.startsWith('.github/'));
// The Bun jobs are cheap and read the app's generated schema, so any change but docs runs them.
const bun = common || paths.length > 0;
// `server/schema.ts` changes the committed Swift schema, which the Bun tests check, so the server alone skips Swift.
const swift = common || paths.some(name => !name.startsWith('server/') && name !== 'wrangler.jsonc');

appendFileSync(output, `bun=${bun}\nswift=${swift}\n`);
