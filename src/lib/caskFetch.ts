import type { Cask } from "./caskTypes";
import { categorize } from "./categories";

const CASK_URL = "https://formulae.brew.sh/api/cask.json";
const ANALYTICS_URL =
  "https://formulae.brew.sh/api/analytics/cask-install/365d.json";

type RawCask = {
  token: string;
  name?: string[];
  desc?: string | null;
  homepage?: string;
  version?: string;
  artifacts?: unknown[];
  deprecated?: boolean;
  deprecation_date?: string | null;
  deprecation_reason?: string | null;
  caveats?: string | null;
  auto_updates?: boolean | null;
  depends_on?: Cask["depends_on"];
};

type AnalyticsResponse = {
  items?: Array<{ cask?: string; count?: string | number }>;
};

function parseCount(raw: string | number | undefined): number {
  if (raw == null) return 0;
  if (typeof raw === "number") return raw;
  return Number(raw.replace(/,/g, "")) || 0;
}

export async function fetchCatalog(): Promise<Cask[]> {
  const [casksRes, analyticsRes] = await Promise.all([
    fetch(CASK_URL),
    fetch(ANALYTICS_URL).catch(() => null),
  ]);

  if (!casksRes.ok) {
    throw new Error(`cask.json fetch failed: ${casksRes.status}`);
  }

  const raw: RawCask[] = await casksRes.json();

  const counts = new Map<string, number>();
  if (analyticsRes && analyticsRes.ok) {
    const a: AnalyticsResponse = await analyticsRes.json();
    for (const item of a.items ?? []) {
      if (item.cask) counts.set(item.cask, parseCount(item.count));
    }
  }

  return raw.map<Cask>((c) => {
    const trimmed: Cask = {
      token: c.token,
      name: c.name ?? [],
      desc: c.desc ?? null,
      homepage: c.homepage ?? "",
      version: c.version ?? "",
      artifacts: c.artifacts ?? [],
      deprecated: !!c.deprecated,
      deprecation_date: c.deprecation_date ?? null,
      deprecation_reason: c.deprecation_reason ?? null,
      caveats: c.caveats ?? null,
      auto_updates: c.auto_updates ?? null,
      depends_on: c.depends_on,
      install_count: counts.get(c.token) ?? 0,
    };
    trimmed.category = categorize(trimmed);
    return trimmed;
  });
}
