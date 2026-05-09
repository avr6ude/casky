import { create } from "zustand";
import type { Cask, CatalogMeta } from "@/lib/caskTypes";
import { readCachedCatalog, writeCachedCatalog } from "@/lib/caskCache";
import { fetchCatalog } from "@/lib/caskFetch";

type CatalogStatus = "idle" | "loading" | "ready" | "error";

type CatalogState = {
  casks: Cask[];
  meta: CatalogMeta | null;
  status: CatalogStatus;
  error: string | null;
  isRevalidating: boolean;
  load: () => Promise<void>;
};

export const useCatalogStore = create<CatalogState>((set, get) => ({
  casks: [],
  meta: null,
  status: "idle",
  error: null,
  isRevalidating: false,

  load: async () => {
    if (get().status === "loading") return;
    set({ status: "loading", error: null });

    try {
      const cached = await readCachedCatalog();

      if (cached.casks && cached.meta) {
        set({
          casks: cached.casks,
          meta: cached.meta,
          status: "ready",
        });

        if (cached.isStale) {
          revalidate(set);
        }
        return;
      }

      const fresh = await fetchCatalog();
      const meta = await writeCachedCatalog(fresh);
      set({ casks: fresh, meta, status: "ready" });
    } catch (e) {
      set({
        status: "error",
        error: e instanceof Error ? e.message : String(e),
      });
    }
  },
}));

async function revalidate(
  set: (
    partial:
      | Partial<CatalogState>
      | ((s: CatalogState) => Partial<CatalogState>),
  ) => void,
) {
  set({ isRevalidating: true });
  try {
    const fresh = await fetchCatalog();
    const meta = await writeCachedCatalog(fresh);
    set({ casks: fresh, meta, isRevalidating: false });
  } catch {
    set({ isRevalidating: false });
  }
}
