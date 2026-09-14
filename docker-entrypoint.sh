#!/bin/sh
set -e

# Ensure data and log directories exist
mkdir -p /app/data /app/logs 2>/dev/null || true

# If running as root (e.g. on VPS with root volume mounts), ensure node user owns the data dir
if [ "$(id -u)" = "0" ]; then
  chown -R node:node /app/data /app/logs 2>/dev/null || true
fi

# Sync database schema with Prisma
if [ -d "/app/prisma/migrations" ] && [ "$(ls -A /app/prisma/migrations 2>/dev/null)" ]; then
  echo ">>> [SvelteKitStarter] Applying database migrations..."
  npx prisma migrate deploy || npx prisma db push --skip-generate
else
  echo ">>> [SvelteKitStarter] Synchronizing database schema..."
  npx prisma db push --skip-generate
fi

# Initialize standard demo & admin users
if [ -f "/app/scripts/seed-users.ts" ]; then
  echo ">>> [SvelteKitStarter] Seeding standard demo & admin accounts..."
  npx tsx /app/scripts/seed-users.ts || echo ">>> [SvelteKitStarter] User seeding completed or skipped"
fi

# If started as root, drop privileges to node user
if [ "$(id -u)" = "0" ] && command -v gosu >/dev/null 2>&1; then
  exec gosu node "$@"
else
  exec "$@"
fi
