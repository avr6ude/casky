import { create } from "zustand";
import { persist } from "zustand/middleware";

type CartState = {
  tokens: string[];
  remove: (token: string) => void;
  toggle: (token: string) => void;
  clear: () => void;
  setAll: (tokens: string[]) => void;
};

export const useCartStore = create<CartState>()(
  persist(
    (set) => ({
      tokens: [],
      remove: (token) =>
        set((s) => ({ tokens: s.tokens.filter((t) => t !== token) })),
      toggle: (token) =>
        set((s) =>
          s.tokens.includes(token)
            ? { tokens: s.tokens.filter((t) => t !== token) }
            : { tokens: [...s.tokens, token] },
        ),
      clear: () => set({ tokens: [] }),
      setAll: (tokens) => set({ tokens: Array.from(new Set(tokens)) }),
    }),
    { name: "casky:cart:v1" },
  ),
);
