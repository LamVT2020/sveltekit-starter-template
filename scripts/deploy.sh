#!/usr/bin/env bash
# Standard Canonical 7-Step Deployment Script for SvelteKit Projects
set -euo pipefail

APP_NAME="sveltekit-starter-template"
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${DEPLOY_DIR}"

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

APP_PORT="${PORT:-3000}"
HEALTH_URL="http://localhost:${APP_PORT}/api/health"

echo "=================================================="
echo "🚀 Starting Deployment for ${APP_NAME} on port ${APP_PORT}"
echo "=================================================="

# Step 1: Pre-backup database
echo "📦 [Step 1/7] Backing up database..."
if npm run | grep -q "backup"; then
  npm run backup || echo "⚠️ Pre-backup completed with warnings (non-fatal)"
else
  echo "ℹ️ No backup script defined, skipping."
fi

# Step 2: Fetch latest code
echo "📥 [Step 2/7] Pulling latest code..."
if [ -d .git ]; then
  git pull origin main || git pull origin master || echo "⚠️ Git pull failed or already up to date"
fi

# Step 3: Install production dependencies
echo "📦 [Step 3/7] Installing dependencies..."
npm install --no-audit --no-fund

# Step 4: Run Prisma migrations and seed standard users
echo "🗄️ [Step 4/7] Synchronizing database schema and seeding users..."
npx prisma generate
npx prisma db push --skip-generate
if npm run | grep -q "seed:users"; then
  npm run seed:users
fi

# Step 5: Build production bundle
echo "🔨 [Step 5/7] Building SvelteKit production bundle..."
npm run build

# Step 6: Reload / Start PM2 application
echo "🔄 [Step 6/7] Reloading application with PM2..."
if command -v pm2 >/dev/null 2>&1; then
  pm2 reload ecosystem.config.cjs || pm2 start ecosystem.config.cjs
  pm2 save
else
  echo "⚠️ PM2 not found in PATH. Please start application manually with 'npm run start'."
fi

# Step 7: Zero-downtime Health Check
echo "🩺 [Step 7/7] Verifying application health check..."
ATTEMPTS=0
MAX_ATTEMPTS=15
until curl -s -f -m 3 "${HEALTH_URL}" > /dev/null; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
    echo "❌ [Deployment Failed] Health check did not return HTTP 200 within timeout at ${HEALTH_URL}"
    exit 1
  fi
  sleep 1
done

echo "=================================================="
echo "✅ Deployment completed successfully for ${APP_NAME}!"
echo "🌐 App running at http://localhost:${APP_PORT}"
echo "=================================================="
