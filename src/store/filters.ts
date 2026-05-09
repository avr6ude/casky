import { create } from "zustand";
import type { CaskCategory } from "@/lib/caskTypes";

type FilterState = {
  query: string;
  category: CaskCategory | "all";
  setQuery: (q: string) => void;
  setCategory: (c: CaskCategory | "all") => void;
};

export const useFiltersStore = create<FilterState>((set) => ({
  query: "",
  category: "all",
  setQuery: (q) => set({ query: q }),
  setCategory: (c) => set({ category: c }),
}));
