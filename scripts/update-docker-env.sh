#!/usr/bin/env bash

# ==============================================================================
# ⚡ SvelteKit Starter - Docker Instant Environment (.env) Reload Script
# ==============================================================================
# Usage on VPS:
#   ./scripts/update-docker-env.sh (or: npm run update:docker:env)
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

APP_NAME="starter-template"
APP_PORT="3005"

echo -e "${C_CYAN}${C_BOLD}"
echo "================================================================="
echo "   ⚡ SVELTEKIT STARTER - DOCKER INSTANT ENV CONFIG RELOAD       "
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

# 1. Resolve Docker Compose command
DOCKER_COMPOSE_CMD=""
if docker compose version &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo -e "${C_RED}❌ Error: docker compose is not installed!${C_RESET}"
    exit 1
fi

# 2. Check external VPS config if present
EXTERNAL_CONFIG="/home/deploy/configs/${APP_NAME}/.env"
if [ -f "$EXTERNAL_CONFIG" ]; then
    echo -e "${C_GREEN}✔ Synchronizing external VPS configuration:${C_RESET} $EXTERNAL_CONFIG"
    ln -sfn "$EXTERNAL_CONFIG" .env 2>/dev/null || cp "$EXTERNAL_CONFIG" .env
fi

get_env_val() {
    local key="$1"
    if [ -f ".env" ]; then
        (grep -E "^[[:space:]]*${key}=" .env 2>/dev/null || true) | tail -n 1 | cut -d '=' -f2- | sed -e 's/^[[:space:]]*["'"'"']//' -e 's/["'"'"'][[:space:]]*$//' -e 's/[[:space:]]*#.*$//'
    fi
}

DEMO_STATUS="$(get_env_val ENABLE_DEMO_LOGIN)"
if [ "$DEMO_STATUS" = "false" ]; then
    DEMO_LABEL="${C_RED}DISABLED (Tắt - Ẩn nút demo, chặn 403 /demo)${C_RESET}"
else
    DEMO_LABEL="${C_GREEN}ENABLED (Bật - Cho phép 1-Click Demo)${C_RESET}"
fi

echo -e "\n${C_BOLD}${C_MAGENTA}📋 CURRENT APPLIED CONFIGURATION:${C_RESET}"
echo -e "  • ${C_BOLD}PORT:${C_RESET} ${APP_PORT}"
echo -e "  • ${C_BOLD}ENABLE_DEMO_LOGIN:${C_RESET} ${DEMO_LABEL}"

# 3. Recreate containers with updated .env (Zero-rebuild, ~2s)
echo -e "\n${C_CYAN}⚡ Recreating containers with new .env (--force-recreate)...${C_RESET}"
$DOCKER_COMPOSE_CMD up -d --force-recreate

# 4. Quick health check
echo -e "\n${C_CYAN}🔍 Verifying container health on port ${APP_PORT}...${C_RESET}"
sleep 2

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${APP_PORT}/api/health" 2>/dev/null || echo "000")

echo -e "\n${C_BOLD}${C_GREEN}=================================================================${C_RESET}"
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "307" ]; then
    echo -e "${C_BOLD}${C_GREEN}   🎉 DOCKER ENV RELOAD SUCCESSFUL!                              ${C_RESET}"
    echo -e "   App: ${C_BOLD}SvelteKit Starter${C_RESET} is ONLINE on port ${C_BOLD}${APP_PORT}${C_RESET} (HTTP ${HTTP_CODE})"
else
    echo -e "${C_BOLD}${C_YELLOW}   ⚠ Container restarted (HTTP: ${HTTP_CODE})                         ${C_RESET}"
    echo -e "   Check live logs: ${C_BOLD}$DOCKER_COMPOSE_CMD logs -f sveltekit-starter-web${C_RESET}"
fi
echo -e "   🔐 Demo Login Status: ${DEMO_LABEL}"
echo -e "   🌐 Local URL         : http://127.0.0.1:${APP_PORT}"
echo -e "   🌐 Public URL        : http://<VPS_IP>:${APP_PORT}"
echo -e "${C_BOLD}${C_GREEN}=================================================================${C_RESET}\n"
