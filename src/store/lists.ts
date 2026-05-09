import { create } from "zustand";
import { persist } from "zustand/middleware";

export interface SavedList {
  id: string;
  name: string;
  tokens: string[];
  createdAt: number;
}

type ListsState = {
  lists: SavedList[];
  save: (name: string, tokens: string[]) => SavedList;
  remove: (id: string) => void;
  rename: (id: string, name: string) => void;
};

function newId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

export const useListsStore = create<ListsState>()(
  persist(
    (set) => ({
      lists: [],
      save: (name, tokens) => {
        const list: SavedList = {
          id: newId(),
          name: name.trim() || "Untitled",
          tokens: Array.from(new Set(tokens)),
          createdAt: Date.now(),
        };
        set((s) => ({ lists: [list, ...s.lists] }));
        return list;
      },
      remove: (id) =>
        set((s) => ({ lists: s.lists.filter((l) => l.id !== id) })),
      rename: (id, name) =>
        set((s) => ({
          lists: s.lists.map((l) =>
            l.id === id ? { ...l, name: name.trim() || l.name } : l,
          ),
        })),
    }),
    { name: "casky:lists:v1" },
  ),
);
