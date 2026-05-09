import { create } from "zustand";
import type { CaskCategory } from "@/lib/caskTypes";

export type SortMode = "popular" | "alpha" | "recent";

type FilterState = {
  query: string;
  category: CaskCategory | "all";
  sort: SortMode;
  hideDeprecated: boolean;
  setQuery: (q: string) => void;
  setCategory: (c: CaskCategory | "all") => void;
  setSort: (s: SortMode) => void;
  setHideDeprecated: (v: boolean) => void;
  reset: () => void;
};

export const useFiltersStore = create<FilterState>((set) => ({
  query: "",
  category: "all",
  sort: "popular",
  hideDeprecated: true,

  setQuery: (q) => set({ query: q }),
  setCategory: (c) => set({ category: c }),
  setSort: (s) => set({ sort: s }),
  setHideDeprecated: (v) => set({ hideDeprecated: v }),

  reset: () =>
    set({ query: "", category: "all", sort: "popular", hideDeprecated: true }),
}));
