#!/bin/sh
set -e

# Ensure data and log directories exist
mkdir -p /app/data /app/logs 2>/dev/null || true

# If running as root (e.g. on VPS with root volume mounts), ensure node user owns the data dir
if [ "$(id -u)" = "0" ]; then
  chown -R node:node /app/data /app/logs 2>/dev/null || true
fi

run_as_node() {
  if [ "$(id -u)" = "0" ]; then
    gosu node "$@"
  else
    "$@"
  fi
}

# Sync database schema with Prisma
if [ "${RUN_MIGRATIONS:-}" = "true" ] || { [ "${1:-}" = "node" ] && [ "${RUN_MIGRATIONS:-}" != "false" ]; }; then
  echo ">>> [SvelteKitStarter] Synchronizing database schema..."
  if [ -d "/app/prisma/migrations" ] && [ "$(ls -A /app/prisma/migrations 2>/dev/null)" ]; then
    run_as_node npx --no-install prisma migrate deploy
  else
    run_as_node npx --no-install prisma db push --skip-generate
  fi

  # Initialize standard demo & admin users
  if [ "${SEED_USERS:-false}" = "true" ] && [ -f "/app/scripts/seed-users.ts" ]; then
    echo ">>> [SvelteKitStarter] Seeding standard demo & admin accounts..."
    run_as_node npx --no-install tsx /app/scripts/seed-users.ts
  fi
fi

# If started as root, drop privileges to node user
if [ "$(id -u)" = "0" ] && command -v gosu >/dev/null 2>&1; then
  exec gosu node "$@"
else
  exec "$@"
fi
