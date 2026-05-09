import { useMemo } from "react";
import { useCatalogStore } from "@/store/catalog";
import { useFiltersStore } from "@/store/filters";
import { createFuse } from "@/lib/fuzzy";
import type { Cask } from "@/lib/caskTypes";

export function useFilteredCasks(): Cask[] {
  const casks = useCatalogStore((s) => s.casks);
  const query = useFiltersStore((s) => s.query);
  const category = useFiltersStore((s) => s.category);
  const sort = useFiltersStore((s) => s.sort);
  const hideDeprecated = useFiltersStore((s) => s.hideDeprecated);

  const fuse = useMemo(() => createFuse(casks), [casks]);

  return useMemo(() => {
    let pool: Cask[] = casks;

    if (hideDeprecated) {
      pool = pool.filter((c) => !c.deprecated);
    }

    if (category !== "all") {
      pool = pool.filter((c) => c.category === category);
    }

    if (query.trim().length >= 2) {
      const hits = fuse.search(query.trim()).map((h) => h.item);
      const allowed = new Set(pool.map((c) => c.token));
      pool = hits.filter((c) => allowed.has(c.token));
    } else {
      pool = [...pool];
      switch (sort) {
        case "alpha":
          pool.sort((a, b) =>
            (a.name[0] ?? a.token).localeCompare(b.name[0] ?? b.token),
          );
          break;
        case "recent":
          pool.sort((a, b) => (b.version > a.version ? 1 : -1));
          break;
        case "popular":
        default:
          pool.sort(
            (a, b) => (b.install_count ?? 0) - (a.install_count ?? 0),
          );
      }
    }

    return pool;
  }, [casks, query, category, sort, hideDeprecated, fuse]);
}
