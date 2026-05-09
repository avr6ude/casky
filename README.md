# casky

Web UI over the Homebrew Cask catalog. Pick apps from the grid, get back a `brew install --cask` line, a Brewfile, or a curl one-liner that bootstraps Homebrew if missing.

A modern revival of the dead `macapps.link` idea, built on top of the live Homebrew catalog.

## Stack

- bun + Vite + React 19 + TypeScript
- Park UI (Ark UI primitives) + Panda CSS, violet accent + sand gray
- Zustand for cart + filters + catalog state
- Fuse.js for fuzzy search across ~7000 casks
- React Virtuoso for the virtualized grid
- Framer Motion for the cart bar's panel expansion
- IndexedDB (`idb-keyval`) cache with stale-while-revalidate

Catalog comes live from `formulae.brew.sh/api/cask.json` on first visit, cached locally and refreshed in the background after 24 h.

## Develop

```sh
bun install
bun dev
```

App runs at `http://localhost:5173` (or next free port).

## Build

```sh
bun run build
```

Outputs static files to `dist/`. Approx 750 KB JS gzipped, 13 KB CSS.

## Deploy to a VPS (Caddy)

This is a static SPA — any web server that serves files and supports SPA fallback works. Path of least resistance on a Linux VPS is Caddy.

### 1. Build

```sh
bun run build
```

### 2. Upload `dist/` to the VPS

```sh
rsync -avz --delete dist/ user@your-vps:/var/www/casky/
```

Or use the included script:

```sh
CASKY_VPS=user@your-vps:/var/www/casky ./scripts/deploy.sh
```

### 3. Caddyfile

Add this block on the VPS (typically `/etc/caddy/Caddyfile`):

```caddyfile
casky.app {
  root * /var/www/casky
  encode gzip zstd
  try_files {path} /index.html
  file_server

  header Cache-Control "public, max-age=31536000, immutable"
  @html path /index.html
  header @html Cache-Control "public, max-age=0, must-revalidate"
}
```

The `try_files {path} /index.html` line is critical — SPA paths like `/share/<encoded>` need to fall back to `index.html` so the client decodes them.

### 4. Reload Caddy

```sh
sudo systemctl reload caddy
```

Caddy auto-issues a Let's Encrypt cert on first request, assuming DNS points at the VPS.

## Other hosts

| Host | Notes |
|---|---|
| nginx | `try_files $uri /index.html;` inside `location /`. |
| Apache | `mod_rewrite` with `RewriteRule ^ index.html [L]` for non-existing files. |
| Static-hosting Workers / Pages-style | Configure SPA fallback to `/index.html`. |
| GitHub Pages | Works, but `/share/...` paths 404 unless you switch to a hash router. |

## Configure

Update `src/data/config.ts` with your URLs before deploying:

```ts
export const config = {
  donateUrl: "https://ko-fi.com/avrdude",
  repoUrl: "https://github.com/<you>/casky",
  homepage: "https://casky.app",
};
```

## Add a curated kit

Edit `src/data/collections.ts` and append to the `collections` array:

```ts
{
  slug: "your-kit",
  emoji: "📦",
  title: "Your kit name",
  desc: "One-line description.",
  tokens: ["raycast", "cursor", "..."],
}
```

Tokens that don't exist in the live catalog are filtered out at runtime — no need to keep them in lock-step with Homebrew.

## License

MIT for the casky source. Cask metadata comes from the Homebrew project.
