import { expect, test } from "bun:test";
import {
  brewInstallCommand,
  brewfile,
  isQualifiedToken,
  splitTap,
} from "./outputFormatters";

test("splitTap parses owner/repo/name, rejects plain and malformed", () => {
  expect(splitTap("charmbracelet/tap/mods")).toEqual({
    tap: "charmbracelet/tap",
    name: "mods",
  });
  expect(splitTap("firefox")).toBeNull();
  expect(splitTap("owner/repo")).toBeNull();
  expect(splitTap("a/b/c/d")).toBeNull();
  expect(isQualifiedToken("charmbracelet/tap/mods")).toBe(true);
  expect(isQualifiedToken("firefox")).toBe(false);
});

test("brewInstallCommand passes qualified tokens through for auto-tap", () => {
  expect(brewInstallCommand(["firefox", "charmbracelet/tap/mods"])).toBe(
    "brew install --cask firefox charmbracelet/tap/mods",
  );
});

test("brewfile emits deduped tap lines and short cask names", () => {
  const out = brewfile([
    "firefox",
    "charmbracelet/tap/mods",
    "charmbracelet/tap/glow",
    "acme/x/tool",
  ]);
  const lines = out.split("\n");
  expect(lines.filter((l) => l === 'tap "charmbracelet/tap"')).toHaveLength(1);
  expect(lines).toContain('tap "acme/x"');
  expect(lines).toContain('cask "firefox"');
  expect(lines).toContain('cask "mods"');
  expect(lines).toContain('cask "glow"');
  expect(lines).toContain('cask "tool"');
  // tap lines come before cask lines
  expect(out.indexOf('tap "')).toBeLessThan(out.indexOf('cask "'));
});

test("brewfile with no custom taps emits no tap block", () => {
  expect(brewfile(["firefox", "slack"])).not.toContain('tap "');
});

test("empty cart yields empty output", () => {
  expect(brewfile([])).toBe("");
  expect(brewInstallCommand([])).toBe("");
});
