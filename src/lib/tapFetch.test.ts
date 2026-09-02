import { afterEach, expect, mock, test } from "bun:test";
import {
  fetchTapCaskTokens,
  normalizeTapName,
  resolveTapRepo,
} from "./tapFetch";

const realFetch = globalThis.fetch;
afterEach(() => {
  globalThis.fetch = realFetch;
});

test("resolveTapRepo adds homebrew- prefix unless present", () => {
  expect(resolveTapRepo("charmbracelet/tap")).toEqual({
    owner: "charmbracelet",
    repo: "homebrew-tap",
  });
  expect(resolveTapRepo("user/homebrew-foo")).toEqual({
    owner: "user",
    repo: "homebrew-foo",
  });
  expect(resolveTapRepo(" charmbracelet/tap/ ")).toEqual({
    owner: "charmbracelet",
    repo: "homebrew-tap",
  });
});

test("resolveTapRepo rejects malformed names", () => {
  expect(() => resolveTapRepo("just-a-name")).toThrow();
  expect(() => resolveTapRepo("a/b/c")).toThrow();
  expect(() => resolveTapRepo("/")).toThrow();
});

test("normalizeTapName trims, strips slashes, lowercases", () => {
  expect(normalizeTapName("  Charmbracelet/Tap/ ")).toBe("charmbracelet/tap");
});

function mockFetch(status: number, body: unknown) {
  globalThis.fetch = mock(async () => ({
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
  })) as unknown as typeof fetch;
}

test("fetchTapCaskTokens returns sorted unique tokens from .rb files", async () => {
  mockFetch(200, [
    { name: "zed.rb", type: "file" },
    { name: "mods.rb", type: "file" },
    { name: "README.md", type: "file" },
    { name: "sub", type: "dir" },
  ]);
  expect(await fetchTapCaskTokens("acme/tap")).toEqual(["mods", "zed"]);
});

test("fetchTapCaskTokens maps 404 and 403 to friendly errors", async () => {
  mockFetch(404, {});
  await expect(fetchTapCaskTokens("acme/nope")).rejects.toThrow(/Casks/);
  mockFetch(403, {});
  await expect(fetchTapCaskTokens("acme/tap")).rejects.toThrow(/rate limit/);
});

test("fetchTapCaskTokens throws when tap has no casks", async () => {
  mockFetch(200, [{ name: "LICENSE", type: "file" }]);
  await expect(fetchTapCaskTokens("acme/tap")).rejects.toThrow(/No casks/);
});
