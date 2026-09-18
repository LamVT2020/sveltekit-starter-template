#!/usr/bin/env bash

# ==============================================================================
# ⚡ SvelteKit Starter - Instant Environment (.env) Reload Script
# ==============================================================================
# Usage on VPS:
#   ./scripts/update-env.sh (or: npm run update:env)
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
echo "   ⚡ SVELTEKIT STARTER - INSTANT ENVIRONMENT CONFIG RELOAD      "
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

# 1. Detect active .env configuration file
APP_NAME="starter-template"
EXTERNAL_CONFIGS=(
    "/home/deploy/configs/${APP_NAME}/.env"
    "/home/deploy/configs/${APP_NAME}.env"
    "/home/deploy/configs/${APP_NAME}"
    "/home/deploy/configs/.env"
    "/home/deploy/config/${APP_NAME}/.env"
    "/home/deploy/config/${APP_NAME}.env"
    "/home/deploy/config/${APP_NAME}"
    "/home/deploy/config/.env"
)

EXTERNAL_FOUND=""
for cfg in "${EXTERNAL_CONFIGS[@]}"; do
    if [ -f "$cfg" ]; then
        EXTERNAL_FOUND="$cfg"
        break
    fi
done

if [ -n "$EXTERNAL_FOUND" ]; then
    echo -e "${C_GREEN}✔ Found external VPS configuration:${C_RESET} ${C_BOLD}${EXTERNAL_FOUND}${C_RESET}"
    ln -sfn "$EXTERNAL_FOUND" .env
fi

if [ ! -f ".env" ]; then
    echo -e "${C_RED}❌ Error: No .env configuration file found!${C_RESET}"
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

DEMO_STATUS="$(get_env_val ENABLE_DEMO_LOGIN)"
if [ "$DEMO_STATUS" = "false" ]; then
    DEMO_LABEL="${C_RED}DISABLED (Đã tắt - Ẩn nút Demo, chặn 403 API/demo)${C_RESET}"
else
    DEMO_LABEL="${C_GREEN}ENABLED (Đang bật - Cho phép 1-Click Demo)${C_RESET}"
fi

echo -e "\n${C_BOLD}${C_MAGENTA}📋 CURRENT APPLIED CONFIGURATION:${C_RESET}"
echo -e "  • ${C_BOLD}PORT:${C_RESET} ${APP_PORT}"
echo -e "  • ${C_BOLD}ENABLE_DEMO_LOGIN:${C_RESET} ${DEMO_LABEL}"
DATABASE_URL_VAL="$(get_env_val DATABASE_URL)"
echo -e "  • ${C_BOLD}DATABASE_URL:${C_RESET} ${DATABASE_URL_VAL:-file:./dev.db}"

# 2. Sync admin accounts in DB to ensure lamvt is active
if grep -q '"seed:users"' package.json 2>/dev/null; then
    echo -e "\n${C_CYAN}👤 Synchronizing admin accounts in database...${C_RESET}"
    npm run seed:users 2>/dev/null || true
fi

# 3. Reload PM2 services with updated environment variables
echo -e "\n${C_CYAN}⚡ Reloading PM2 processes with updated environment (--update-env)...${C_RESET}"
PM2_CMD="pm2"
if ! command -v pm2 &> /dev/null; then
    if command -v npx &> /dev/null; then
        PM2_CMD="npx pm2"
    fi
fi

if [ -f "ecosystem.config.cjs" ]; then
    $PM2_CMD restart ecosystem.config.cjs --update-env || $PM2_CMD startOrRestart ecosystem.config.cjs --env production --update-env
    $PM2_CMD save 2>/dev/null || true
    echo -e "${C_GREEN}✔ PM2 environment successfully reloaded.${C_RESET}"
else
    echo -e "${C_RED}❌ Error: ecosystem.config.cjs not found!${C_RESET}"
    exit 1
fi

# 4. Quick health check
echo -e "\n${C_CYAN}🔍 Verifying service status on port ${APP_PORT}...${C_RESET}"
sleep 1.5

HEALTH_CHECK_URL="http://127.0.0.1:${APP_PORT}/"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" 2>/dev/null || echo "000")

echo -e "\n${C_BOLD}${C_GREEN}=================================================================${C_RESET}"
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "307" ]; then
    echo -e "${C_BOLD}${C_GREEN}   🎉 ENVIRONMENT RELOAD SUCCESSFUL!                            ${C_RESET}"
    echo -e "   App: ${C_BOLD}SvelteKit Starter${C_RESET} is ONLINE on port: ${C_BOLD}${APP_PORT}${C_RESET} (HTTP ${HTTP_STATUS})"
else
    echo -e "${C_BOLD}${C_YELLOW}   ⚠ RELOAD COMPLETED (HTTP Status: ${HTTP_STATUS})                     ${C_RESET}"
    echo -e "   Inspect runtime logs with: ${C_BOLD}pm2 logs sveltekit-starter-template --lines 50${C_RESET}"
fi
echo -e "   🔐 Demo Login Status: ${DEMO_LABEL}"
echo -e "   🌐 Local URL         : http://127.0.0.1:${APP_PORT}"
echo -e "   🌐 Public URL        : http://<VPS_IP>:${APP_PORT}"
echo -e "${C_BOLD}${C_GREEN}=================================================================${C_RESET}\n"
