/**
 * `NameKey` in the app, for items the server writes. The rules are frozen and must match the Swift text exactly, since an
 * item's id holds its key: lowercase, decompose (NFKD), drop combining marks, turn every run of anything but letters
 * and digits into one space, trim. `name-key.test.ts` runs the cases `Tests/AppTests/NameKeyTests.swift` pins.
 */
export function nameKey(name: string): string | null {
  const words: string[] = [];
  let word = "";
  for (const char of name.toLowerCase().normalize("NFKD")) {
    if (/\p{M}/u.test(char)) continue;
    if (/[\p{L}\p{N}]/u.test(char)) {
      word += char;
    } else if (word) {
      words.push(word);
      word = "";
    }
  }
  if (word) words.push(word);
  return words.length ? words.join(" ") : null;
}
