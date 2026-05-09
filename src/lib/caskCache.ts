import { get, set } from "idb-keyval";
import type { Cask, CatalogMeta } from "./caskTypes";
import { STALE_AFTER_MS } from "./caskTypes";

const KEY_CASKS = "casky:catalog:v2";
const KEY_META = "casky:catalog-meta:v2";

export async function readCachedCatalog(): Promise<{
  casks: Cask[] | null;
  meta: CatalogMeta | null;
  isStale: boolean;
}> {
  const [casks, meta] = await Promise.all([
    get<Cask[]>(KEY_CASKS),
    get<CatalogMeta>(KEY_META),
  ]);

  if (!casks || !meta) {
    return { casks: null, meta: null, isStale: true };
  }
  const isStale = Date.now() - meta.fetchedAt > STALE_AFTER_MS;
  return { casks, meta, isStale };
}

export async function writeCachedCatalog(casks: Cask[]): Promise<CatalogMeta> {
  const meta: CatalogMeta = { fetchedAt: Date.now(), count: casks.length };
  await Promise.all([set(KEY_CASKS, casks), set(KEY_META, meta)]);
  return meta;
}
