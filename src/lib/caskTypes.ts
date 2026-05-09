export type Cask = {
  token: string;
  name: string[];
  desc: string | null;
  homepage: string;
  version: string;
  artifacts: unknown[];
  deprecated: boolean;
  deprecation_date: string | null;
  deprecation_reason: string | null;
  caveats: string | null;
  auto_updates: boolean | null;
  depends_on?: {
    cask?: string[];
    formula?: string[];
    macos?: unknown;
  };
  install_count?: number;
  category?: CaskCategory;
};

export type CaskCategory =
  | "ai"
  | "browsers"
  | "communication"
  | "developer"
  | "design"
  | "audio"
  | "video"
  | "games"
  | "productivity"
  | "privacy"
  | "writing"
  | "finance"
  | "system"
  | "network"
  | "files"
  | "education"
  | "utilities"
  | "other";

export type CatalogMeta = {
  fetchedAt: number;
  count: number;
};

export const STALE_AFTER_MS = 24 * 60 * 60 * 1000;
