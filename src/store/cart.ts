import { create } from "zustand";
import { persist } from "zustand/middleware";

type CartState = {
  tokens: string[];
  add: (token: string) => void;
  remove: (token: string) => void;
  toggle: (token: string) => void;
  clear: () => void;
  has: (token: string) => boolean;
  setAll: (tokens: string[]) => void;
};

export const useCartStore = create<CartState>()(
  persist(
    (set, get) => ({
      tokens: [],
      add: (token) =>
        set((s) => (s.tokens.includes(token) ? s : { tokens: [...s.tokens, token] })),
      remove: (token) =>
        set((s) => ({ tokens: s.tokens.filter((t) => t !== token) })),
      toggle: (token) =>
        set((s) =>
          s.tokens.includes(token)
            ? { tokens: s.tokens.filter((t) => t !== token) }
            : { tokens: [...s.tokens, token] },
        ),
      clear: () => set({ tokens: [] }),
      has: (token) => get().tokens.includes(token),
      setAll: (tokens) => set({ tokens: Array.from(new Set(tokens)) }),
    }),
    { name: "casky:cart:v1" },
  ),
);
