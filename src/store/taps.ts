import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Cask } from "@/lib/caskTypes";
import { fetchTapCaskTokens, normalizeTapName } from "@/lib/tapFetch";

export type Tap = {
  name: string; // owner/name, normalized
  tokens: string[]; // bare cask tokens, e.g. "mods"
  addedAt: number;
};

type TapsState = {
  taps: Tap[];
  add: (name: string) => Promise<Tap>;
  remove: (name: string) => void;
};

export const useTapsStore = create<TapsState>()(
  persist(
    (set, get) => ({
      taps: [],
      add: async (rawName) => {
        const name = normalizeTapName(rawName);
        if (get().taps.some((t) => t.name === name)) {
          throw new Error(`${name} is already added`);
        }
        const tokens = await fetchTapCaskTokens(name);
        const tap: Tap = { name, tokens, addedAt: Date.now() };
        set((s) => ({ taps: [tap, ...s.taps] }));
        return tap;
      },
      remove: (name) =>
        set((s) => ({ taps: s.taps.filter((t) => t.name !== name) })),
    }),
    { name: "casky:taps:v1" },
  ),
);

/** Synthetic catalog entries for a tap's casks. Category is the tap name. */
export function tapToCasks(tap: Tap): Cask[] {
  return tap.tokens.map((t) => ({
    token: `${tap.name}/${t}`,
    name: [t],
    desc: null,
    homepage: "",
    version: "",
    artifacts: [],
    deprecated: false,
    deprecation_date: null,
    deprecation_reason: null,
    caveats: null,
    auto_updates: null,
    install_count: 0,
    category: tap.name,
  }));
}
