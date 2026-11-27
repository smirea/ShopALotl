import { expect, test } from "bun:test";
import { nameKey } from "./name-key";

test("the server makes the same key as the app's NameKey", () => {
  const cases: [string, string | null][] = [
    ["Milk", "milk"],
    ["  Oat   Milk ", "oat milk"],
    ["Crème Fraîche", "creme fraiche"],
    ["CREME-FRAICHE", "creme fraiche"],
    ["Half & Half", "half half"],
    ["M&M's", "m m s"],
    ["7-Up", "7 up"],
    ["2% milk", "2 milk"],
    ["Jalapeño (fresh)", "jalapeno fresh"],
    ["İstanbul simit", "istanbul simit"],
    ["ｆｕｌｌｗｉｄｔｈ", "fullwidth"],
    ["豆腐", "豆腐"],
    ["Müsli", "musli"],
    ["apples", "apples"],
    ["", null],
    ["   ", null],
    ["—", null],
    ["!!!", null],
    ["🥑", null],
  ];
  for (const [name, key] of cases) expect([name, nameKey(name)]).toEqual([name, key]);
});
