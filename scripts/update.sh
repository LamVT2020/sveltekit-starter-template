#!/usr/bin/env bash

# ==============================================================================
# 🔄 SvelteKit Starter - Automated Production Update Script (Code & Schema)
# ==============================================================================
# Usage on VPS:
#   ./scripts/update.sh (or: npm run update)
# ==============================================================================

set -eo pipefail

# ANSI Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_CYAN='\033[36m'
C_MAGENTA='\033[35m'

echo -e "${C_CYAN}${C_BOLD}"
echo "================================================================="
echo "   🔄 SVELTEKIT STARTER - PRODUCTION CODE UPDATE                "
echo "================================================================="
echo -e "${C_RESET}"

# 0. Resolve project working directory
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
else
    PROJECT_DIR="$(pwd)"
fi
cd "$PROJECT_DIR"
echo -e "${C_YELLOW}📍 Working directory:${C_RESET} $PROJECT_DIR"

# 1. Verify runtime environment (Node.js & npm)
if ! command -v node &> /dev/null; then
    echo -e "${C_RED}❌ Error: Node.js is not installed!${C_RESET}"
    exit 1
fi

get_env_val() {
    local key="$1"
    if [ -f ".env" ]; then
        (grep -E "^[[:space:]]*${key}=" .env 2>/dev/null || true) | tail -n 1 | cut -d '=' -f2- | sed -e 's/^[[:space:]]*["'"'"']//' -e 's/["'"'"'][[:space:]]*$//' -e 's/[[:space:]]*#.*$//'
    fi
}

APP_PORT="$(get_env_val PORT)"
if [ -z "$APP_PORT" ]; then
    APP_PORT="3005"
fi

# 2. Create database backup snapshot before updating
echo -e "\n${C_CYAN}📦 Step 1/6: Creating database snapshot backup...${C_RESET}"
mkdir -p data logs backups
if [ -f "prisma/dev.db" ] || [ -f "dev.db" ] || [ -f "data/app.db" ]; then
    if grep -q '"backup"' package.json 2>/dev/null; then
        npm run backup 2>/dev/null || true
    fi
fi

# 3. Pull latest git commits
if [ -d ".git" ]; then
    echo -e "\n${C_CYAN}📥 Step 2/6: Pulling latest changes from Git...${C_RESET}"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git pull origin "$CURRENT_BRANCH" || echo -e "${C_YELLOW}  Notice: Git pull had conflicts or local modifications; continuing build...${C_RESET}"
fi

# 4. Install dependencies
echo -e "\n${C_CYAN}📦 Step 3/6: Installing/updating npm dependencies...${C_RESET}"
npm install --no-audit --no-fund

# 5. Synchronize Prisma Database schema & ensure admin accounts
echo -e "\n${C_CYAN}🗄️ Step 4/6: Updating database schema & verifying users...${C_RESET}"
npx prisma generate
npx prisma db push --skip-generate

if grep -q '"seed:users"' package.json 2>/dev/null; then
    npm run seed:users 2>/dev/null || true
fi

# 6. Build SvelteKit production bundle
echo -e "\n${C_CYAN}🛠️ Step 5/6: Building production bundle...${C_RESET}"
npm run build

if [ ! -f "build/index.js" ]; then
    echo -e "${C_RED}❌ Error: Build failed, build/index.js was not generated!${C_RESET}"
    exit 1
fi
echo -e "${C_GREEN}✔ Build successful (build/index.js ready)${C_RESET}"

# 7. Restart PM2 services with updated environment
echo -e "\n${C_CYAN}⚡ Step 6/6: Restarting services via PM2 (--update-env)...${C_RESET}"
PM2_CMD="pm2"
if ! command -v pm2 &> /dev/null; then
    if command -v npx &> /dev/null; then
        PM2_CMD="npx pm2"
    fi
fi

if [ -f "ecosystem.config.cjs" ]; then
    $PM2_CMD restart ecosystem.config.cjs --update-env || $PM2_CMD startOrRestart ecosystem.config.cjs --env production --update-env
    $PM2_CMD save 2>/dev/null || true
    echo -e "${C_GREEN}✔ PM2 services successfully restarted with updated environment.${C_RESET}"
else
    echo -e "${C_RED}❌ Error: ecosystem.config.cjs not found!${C_RESET}"
    exit 1
fi

# 8. Health check verification
echo -e "\n${C_CYAN}🔍 Verifying service status on port ${APP_PORT}...${C_RESET}"
sleep 2

HEALTH_CHECK_URL="http://127.0.0.1:${APP_PORT}/"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" 2>/dev/null || echo "000")

DEMO_STATUS="$(get_env_val ENABLE_DEMO_LOGIN)"
if [ "$DEMO_STATUS" = "false" ]; then
    DEMO_LABEL="${C_RED}DISABLED (Tắt)${C_RESET}"
else
    DEMO_LABEL="${C_GREEN}ENABLED (Bật)${C_RESET}"
fi

echo -e "\n${C_BOLD}${C_GREEN}=================================================================${C_RESET}"
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "307" ]; then
    echo -e "${C_BOLD}${C_GREEN}   🎉 UPDATE SUCCESSFUL!                                         ${C_RESET}"
    echo -e "   App: ${C_BOLD}SvelteKit Starter${C_RESET} is ONLINE on port: ${C_BOLD}${APP_PORT}${C_RESET} (HTTP ${HTTP_STATUS})"
else
    echo -e "${C_BOLD}${C_YELLOW}   ⚠ UPDATE COMPLETED (HTTP Status: ${HTTP_STATUS})                    ${C_RESET}"
    echo -e "   Inspect runtime logs with: ${C_BOLD}pm2 logs sveltekit-starter-template --lines 50${C_RESET}"
fi
echo -e "   🔐 Demo Login: ${DEMO_LABEL}"
echo -e "   🌐 Local URL : http://127.0.0.1:${APP_PORT}"
echo -e "   🌐 Public URL: http://<VPS_IP>:${APP_PORT}"
echo -e "${C_BOLD}${C_GREEN}=================================================================${C_RESET}\n"
