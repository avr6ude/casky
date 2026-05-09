#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${CASKY_VPS:-}" ]]; then
  echo "set CASKY_VPS=user@host:/var/www/casky" >&2
  exit 1
fi

bun run build
rsync -avz --delete dist/ "$CASKY_VPS"
echo "deployed to $CASKY_VPS"
