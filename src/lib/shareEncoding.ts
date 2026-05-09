function toBase64Url(s: string): string {
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64Url(s: string): string {
  let b = s.replace(/-/g, "+").replace(/_/g, "/");
  while (b.length % 4) b += "=";
  return atob(b);
}

export function encodeCart(tokens: string[]): string {
  if (tokens.length === 0) return "";
  return toBase64Url(tokens.join(","));
}

export function decodeCart(encoded: string): string[] {
  if (!encoded) return [];
  try {
    return fromBase64Url(encoded)
      .split(",")
      .map((t) => t.trim())
      .filter(Boolean);
  } catch {
    return [];
  }
}
