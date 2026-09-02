import { create } from "zustand";

// "all", a built-in CaskCategory, or a tap name ("owner/name").
type FilterState = {
  query: string;
  category: string;
  setQuery: (q: string) => void;
  setCategory: (c: string) => void;
};

export const useFiltersStore = create<FilterState>((set) => ({
  query: "",
  category: "all",
  setQuery: (q) => set({ query: q }),
  setCategory: (c) => set({ category: c }),
}));
