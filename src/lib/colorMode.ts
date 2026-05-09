import { useEffect, useState } from "react";

export type ColorMode = "light" | "dark";

const STORAGE_KEY = "casky:color-mode";

function readStored(): string | null {
  try {
    return window.localStorage.getItem(STORAGE_KEY);
  } catch {
    return null;
  }
}

function writeStored(mode: ColorMode): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, mode);
  } catch {
    return;
  }
}

function readInitial(): ColorMode {
  if (typeof window === "undefined") return "light";
  const stored = readStored();
  if (stored === "light" || stored === "dark") return stored;
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function apply(mode: ColorMode) {
  if (typeof document === "undefined") return;
  document.documentElement.setAttribute("data-color-mode", mode);
  if (mode === "dark") {
    document.documentElement.classList.add("dark");
    document.documentElement.classList.remove("light");
  } else {
    document.documentElement.classList.add("light");
    document.documentElement.classList.remove("dark");
  }
}

export function useColorMode() {
  const [mode, setMode] = useState<ColorMode>(readInitial);

  useEffect(() => {
    apply(mode);
    writeStored(mode);
  }, [mode]);

  const toggle = () => setMode((m) => (m === "dark" ? "light" : "dark"));

  return { mode, toggle, setMode };
}

export function bootstrapColorMode() {
  if (typeof window === "undefined") return;
  apply(readInitial());
}
