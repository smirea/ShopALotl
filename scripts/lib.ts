/** What the repository scripts share: the dotenv and env-manager readers. No npm imports. */
import { spawnSync } from "node:child_process";

export type Values = Record<string, string>;

/** Empty values count as unset and are left out. */
export function parseDotenv(text: string): Values {
  const values: Values = {};
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const match = /^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line);
    if (!match) continue;
    const [, key, rest] = match as unknown as [string, string, string];
    const quote = rest[0];
    const quoted = (quote === '"' || quote === "'") && rest.indexOf(quote, 1) > 0;
    const value = quoted
      ? rest.slice(1, rest.indexOf(quote, 1))
      : rest.replace(/(^|\s+)#.*$/, "").trim();
    if (value) values[key] = value;
  }
  return values;
}

/** One environment's values, from the `.env.local` section of `env-manager print`. */
export function readEnv(env: string): Values {
  const result = spawnSync("env-manager", ["print", "shopalotl", "-e", env], { encoding: "utf8" });
  const section = /^\.env\.local$([\s\S]*?)(?:^files$|(?![\s\S]))/m.exec(result.stdout ?? "")?.[1];
  if (result.status !== 0 || section === undefined) {
    throw new Error(
      `env-manager print shopalotl -e ${env} failed. It needs this Mac's AWS credentials.`,
    );
  }
  return parseDotenv(section);
}
