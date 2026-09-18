#!/usr/bin/env bash

# ==============================================================================
# 🔄 SvelteKit Starter - Docker Code & Image Update Script
# ==============================================================================
# Usage on VPS:
#   ./scripts/update-docker.sh (or: npm run update:docker)
# ==============================================================================

set -eo pipefail

# ANSI Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_CYAN='\033[36m'

APP_NAME="starter-template"
APP_PORT="3005"

echo -e "${C_CYAN}${C_BOLD}"
echo "================================================================="
echo "   🔄 SVELTEKIT STARTER - DOCKER CODE & IMAGE UPDATE            "
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

# 2. Database backup before update
echo -e "\n${C_CYAN}📦 Step 1/4: Creating database snapshot backup...${C_RESET}"
mkdir -p data logs backups
if [ -f "data/starter-template.db" ] || [ -f "prisma/dev.db" ] || [ -f "dev.db" ]; then
    if grep -q '"backup"' package.json 2>/dev/null; then
        npm run backup 2>/dev/null || true
    fi
fi

# 3. Pull latest Git commits
if [ -d ".git" ]; then
    echo -e "\n${C_CYAN}📥 Step 2/4: Pulling latest changes from Git...${C_RESET}"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git pull origin "$CURRENT_BRANCH" || echo -e "${C_YELLOW}  Notice: Git pull had conflicts or local modifications; continuing build...${C_RESET}"
fi

# 4. Rebuild image and recreate containers
echo -e "\n${C_CYAN}🔨 Step 3/4: Building new image & restarting containers...${C_RESET}"
$DOCKER_COMPOSE_CMD up -d --build

# 5. Health check verification
echo -e "\n${C_CYAN}🔍 Step 4/4: Verifying container health on port ${APP_PORT}...${C_RESET}"
MAX_RETRIES=15
RETRY_COUNT=0
HEALTHY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${APP_PORT}/api/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "307" ]; then
        HEALTHY=true
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 2
done

echo -e "\n${C_BOLD}${C_GREEN}=================================================================${C_RESET}"
if [ "$HEALTHY" = true ]; then
    echo -e "${C_BOLD}${C_GREEN}   🎉 DOCKER UPDATE SUCCESSFUL!                                  ${C_RESET}"
    echo -e "   App: ${C_BOLD}SvelteKit Starter${C_RESET} is ONLINE on port ${C_BOLD}${APP_PORT}${C_RESET} (HTTP ${HTTP_CODE})"
else
    echo -e "${C_BOLD}${C_YELLOW}   ⚠ Container updated, still initializing (HTTP: ${HTTP_CODE})       ${C_RESET}"
    echo -e "   Check live logs: ${C_BOLD}$DOCKER_COMPOSE_CMD logs -f sveltekit-starter-web${C_RESET}"
fi
echo -e "   🌐 Local URL : http://127.0.0.1:${APP_PORT}"
echo -e "   🌐 Public URL: http://<VPS_IP>:${APP_PORT}"
echo -e "   📋 Logs Web  : $DOCKER_COMPOSE_CMD logs -f sveltekit-starter-web"
echo -e "${C_BOLD}${C_GREEN}=================================================================${C_RESET}\n"
