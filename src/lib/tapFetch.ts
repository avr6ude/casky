// Fetches the cask list for a Homebrew tap straight from GitHub.
//
// ponytail: uses the contents API on `Casks/` only — one request, default
// branch, no auth. Ceiling: taps that shard casks into `Casks/<letter>/`
// subdirs (only homebrew/cask itself does this) or keep casks at repo root
// are not picked up. Upgrade path: git-tree API with recursive=1 once a real
// tap needs it.

export function resolveTapRepo(tap: string): { owner: string; repo: string } {
  const parts = tap.trim().replace(/^\/+|\/+$/g, "").split("/");
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    throw new Error("Tap must look like owner/name");
  }
  const [owner, name] = parts;
  const repo = name.startsWith("homebrew-") ? name : `homebrew-${name}`;
  return { owner, repo };
}

export function normalizeTapName(tap: string): string {
  return tap.trim().replace(/^\/+|\/+$/g, "").toLowerCase();
}

type ContentEntry = { name?: string; type?: string };

export async function fetchTapCaskTokens(tap: string): Promise<string[]> {
  const { owner, repo } = resolveTapRepo(tap);
  const url = `https://api.github.com/repos/${owner}/${repo}/contents/Casks`;

  const res = await fetch(url, {
    headers: { Accept: "application/vnd.github+json" },
  });

  if (res.status === 404) {
    throw new Error(`No Casks/ found in ${normalizeTapName(tap)} — is the tap name right?`);
  }
  if (res.status === 403) {
    throw new Error("GitHub rate limit hit (60/hr). Try again later.");
  }
  if (!res.ok) {
    throw new Error(`GitHub error ${res.status}`);
  }

  const data: unknown = await res.json();
  if (!Array.isArray(data)) {
    throw new Error(`Unexpected response for ${normalizeTapName(tap)}`);
  }

  const tokens = (data as ContentEntry[])
    .filter((e) => e.type === "file" && typeof e.name === "string" && e.name.endsWith(".rb"))
    .map((e) => e.name!.slice(0, -3));

  const uniq = [...new Set(tokens)].sort();
  if (uniq.length === 0) {
    throw new Error(`No casks in ${normalizeTapName(tap)}`);
  }
  return uniq;
}
