import { decodeCart } from "./shareEncoding";

const SHARE_PREFIX = "/share/";

export function readSharedTokensFromLocation(): string[] | null {
  if (typeof window === "undefined") return null;
  const path = window.location.pathname;
  if (!path.startsWith(SHARE_PREFIX)) return null;
  const encoded = path.slice(SHARE_PREFIX.length).replace(/\/$/, "");
  if (!encoded) return null;
  const tokens = decodeCart(encoded);
  return tokens.length > 0 ? tokens : null;
}

export function clearShareFromUrl() {
  if (typeof window === "undefined") return;
  window.history.replaceState(null, "", "/");
}
