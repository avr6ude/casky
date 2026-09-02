import { useDeferredValue, useMemo } from "react";
import { useCatalogStore } from "@/store/catalog";
import { useFiltersStore } from "@/store/filters";
import { useTapsStore, tapToCasks } from "@/store/taps";
import { createFuse } from "@/lib/fuzzy";
import type { Cask } from "@/lib/caskTypes";

const MAX_RESULTS = 300;

export function useFilteredCasks(): Cask[] {
  const casks = useCatalogStore((s) => s.casks);
  const taps = useTapsStore((s) => s.taps);
  const query = useFiltersStore((s) => s.query);
  const category = useFiltersStore((s) => s.category);

  const deferredQuery = useDeferredValue(query);

  const tapCasks = useMemo(() => taps.flatMap(tapToCasks), [taps]);

  const pool = useMemo(() => {
    let p = [...casks, ...tapCasks].filter((c) => !c.deprecated);
    if (category !== "all") p = p.filter((c) => c.category === category);
    return p;
  }, [casks, tapCasks, category]);

  const sortedPool = useMemo(() => {
    return [...pool].sort(
      (a, b) =>
        (b.install_count ?? 0) - (a.install_count ?? 0) ||
        a.token.localeCompare(b.token),
    );
  }, [pool]);

  const fuse = useMemo(() => createFuse(pool), [pool]);

  return useMemo(() => {
    const trimmed = deferredQuery.trim();
    if (trimmed.length >= 2) {
      return fuse.search(trimmed, { limit: MAX_RESULTS }).map((h) => h.item);
    }
    return sortedPool;
  }, [sortedPool, fuse, deferredQuery]);
}
