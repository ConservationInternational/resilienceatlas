#!/bin/bash
# Development entrypoint for the Next.js frontend.
# Skips npm install when package-lock.json hasn't changed.

set -e

git config --global url.https://github.com/.insteadOf ssh://git@github.com/

HASH_FILE="/app/node_modules/.package-lock-hash"
CURRENT_HASH=$(md5sum /app/package-lock.json 2>/dev/null | cut -d' ' -f1 || echo "none")
STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")

if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
  echo "package-lock.json changed, running npm install..."
  npm install
  echo "$CURRENT_HASH" > "$HASH_FILE"
else
  echo "Dependencies up to date, skipping npm install."
fi

exec npm run dev
