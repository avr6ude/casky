export function formatVersion(v: string | null | undefined): string {
  if (!v) return "";
  if (/^\d/.test(v)) return `v${v}`;
  return v;
}

export function formatCount(n: number | null | undefined): string {
  if (!n || n < 1) return "0";
  if (n < 1000) return String(n);
  if (n < 10_000) return `${(n / 1000).toFixed(1)}k`;
  if (n < 1_000_000) return `${Math.round(n / 1000)}k`;
  return `${(n / 1_000_000).toFixed(1)}M`;
}

export function faviconUrl(homepage: string | null | undefined): string | null {
  if (!homepage) return null;
  try {
    const u = new URL(homepage);
    return `https://www.google.com/s2/favicons?domain=${u.hostname}&sz=128`;
  } catch {
    return null;
  }
}
