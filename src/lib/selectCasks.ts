import { useDeferredValue, useMemo } from "react";
import { useCatalogStore } from "@/store/catalog";
import { useFiltersStore } from "@/store/filters";
import { createFuse } from "@/lib/fuzzy";
import type { Cask } from "@/lib/caskTypes";

const MAX_RESULTS = 300;

export function useFilteredCasks(): Cask[] {
  const casks = useCatalogStore((s) => s.casks);
  const query = useFiltersStore((s) => s.query);
  const category = useFiltersStore((s) => s.category);
  const sort = useFiltersStore((s) => s.sort);
  const hideDeprecated = useFiltersStore((s) => s.hideDeprecated);

  const deferredQuery = useDeferredValue(query);

  const pool = useMemo(() => {
    let p = casks;
    if (hideDeprecated) p = p.filter((c) => !c.deprecated);
    if (category !== "all") p = p.filter((c) => c.category === category);
    return p;
  }, [casks, hideDeprecated, category]);

  const sortedPool = useMemo(() => {
    const sorted = [...pool];
    switch (sort) {
      case "alpha":
        sorted.sort((a, b) =>
          (a.name[0] ?? a.token).localeCompare(b.name[0] ?? b.token),
        );
        break;
      case "recent":
        sorted.sort((a, b) => (b.version > a.version ? 1 : -1));
        break;
      case "popular":
      default:
        sorted.sort((a, b) => (b.install_count ?? 0) - (a.install_count ?? 0));
    }
    return sorted;
  }, [pool, sort]);

  const fuse = useMemo(() => createFuse(pool), [pool]);

  return useMemo(() => {
    const trimmed = deferredQuery.trim();
    if (trimmed.length >= 2) {
      return fuse.search(trimmed, { limit: MAX_RESULTS }).map((h) => h.item);
    }
    return sortedPool;
  }, [sortedPool, fuse, deferredQuery]);
}
