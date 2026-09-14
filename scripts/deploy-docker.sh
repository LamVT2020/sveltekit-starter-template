#!/usr/bin/env bash

# ==============================================================================
# 🐳 SvelteKit Starter - Docker Automated Deployment Script (Port 3005)
# ==============================================================================
# Usage:
#   ./scripts/deploy-docker.sh (or: npm run deploy:docker)
# ==============================================================================

set -eo pipefail

# ANSI Colors
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_CYAN='\033[36m'

APP_NAME="sveltekit-starter-template"
APP_PORT="3005"
CONTAINER_NAME="sveltekit-starter-web"

echo -e "${C_CYAN}${C_BOLD}"
echo "================================================================="
echo "   🐳 ${APP_NAME^^} - DOCKER PRODUCTION DEPLOYMENT (Port ${APP_PORT})   "
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

# 1. Verify Docker and Docker Compose
if ! command -v docker &>/dev/null; then
    echo -e "${C_RED}❌ Error: Docker is not installed on this system!${C_RESET}"
    exit 1
fi

DOCKER_COMPOSE_CMD=""
if docker compose version &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo -e "${C_RED}❌ Error: docker compose is not installed!${C_RESET}"
    exit 1
fi

DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
COMPOSE_VER=$($DOCKER_COMPOSE_CMD version --short 2>/dev/null || echo "v2")
echo -e "${C_GREEN}✔ Docker:${C_RESET} v$DOCKER_VER | ${C_GREEN}Docker Compose:${C_RESET} $COMPOSE_VER"

# 2. Inspect and prepare .env configuration
echo -e "\n${C_CYAN}⚙️ [1/4] Checking environment configuration (.env)...${C_RESET}"
EXTERNAL_CONFIG="/home/deploy/configs/${APP_NAME}/.env"
ALT_EXTERNAL_CONFIG="/home/deploy/configs/starter-template/.env"
ALT2_EXTERNAL_CONFIG="/home/deploy/config/${APP_NAME}/.env"

if [ -f "$EXTERNAL_CONFIG" ]; then
    echo -e "${C_GREEN}✔ Using external VPS configuration: ${EXTERNAL_CONFIG}${C_RESET}"
    ln -sfn "$EXTERNAL_CONFIG" .env 2>/dev/null || cp "$EXTERNAL_CONFIG" .env
elif [ -f "$ALT_EXTERNAL_CONFIG" ]; then
    echo -e "${C_GREEN}✔ Using external VPS configuration: ${ALT_EXTERNAL_CONFIG}${C_RESET}"
    ln -sfn "$ALT_EXTERNAL_CONFIG" .env 2>/dev/null || cp "$ALT_EXTERNAL_CONFIG" .env
elif [ -f "$ALT2_EXTERNAL_CONFIG" ]; then
    echo -e "${C_GREEN}✔ Using external VPS configuration: ${ALT2_EXTERNAL_CONFIG}${C_RESET}"
    ln -sfn "$ALT2_EXTERNAL_CONFIG" .env 2>/dev/null || cp "$ALT2_EXTERNAL_CONFIG" .env
elif [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo -e "${C_YELLOW}ℹ .env not found. Copying from .env.example...${C_RESET}"
        cp .env.example .env
    else
        echo -e "${C_RED}❌ Error: Neither .env nor .env.example found!${C_RESET}"
        exit 1
    fi
fi

# Ensure PORT=3005
if ! grep -qE "^[[:space:]]*PORT=" .env 2>/dev/null; then
    echo "PORT=${APP_PORT}" >> .env
    echo -e "${C_GREEN}✔ Set PORT=${APP_PORT} in .env${C_RESET}"
fi

# Generate secrets if missing
generate_secret() {
    if command -v openssl &>/dev/null; then
        openssl rand -hex 32
    else
        date +%s%N | sha256sum | head -c 64
    fi
}

AUTH_SECRET_VAL=$(grep -E "^[[:space:]]*AUTH_SECRET=" .env 2>/dev/null | cut -d '=' -f2- | tr -d '"'"'"' ' || true)
if [ -z "$AUTH_SECRET_VAL" ] || [[ "$AUTH_SECRET_VAL" == *"change-this"* ]]; then
    NEW_SECRET=$(generate_secret)
    sed -i.bak "s|^[[:space:]]*AUTH_SECRET=.*|AUTH_SECRET=\"$NEW_SECRET\"|" .env && rm -f .env.bak
    echo -e "${C_GREEN}✔ Generated secure AUTH_SECRET${C_RESET}"
fi

# 3. Create persistent directories
echo -e "\n${C_CYAN}📁 [2/4] Ensuring persistent storage directories exist...${C_RESET}"
if [ -d "/home/deploy/data" ]; then
    export DATA_DIR="/home/deploy/data/starter-template"
    export LOG_DIR="/home/deploy/logs/starter-template"
    mkdir -p "$DATA_DIR" "$LOG_DIR"
    chmod 777 "$DATA_DIR" "$LOG_DIR" 2>/dev/null || true
    echo -e "${C_GREEN}✔ Using VPS persistent storage at ${DATA_DIR}${C_RESET}"
else
    mkdir -p data logs backups
    chmod 777 data logs 2>/dev/null || true
fi

# 4. Build and start container via Docker Compose
echo -e "\n${C_CYAN}🔨 [3/4] Building and launching container...${C_RESET}"
$DOCKER_COMPOSE_CMD up -d --build

# 5. Health check verification
echo -e "\n${C_CYAN}🔍 [4/4] Verifying container health on port ${APP_PORT}...${C_RESET}"
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
    echo -e "${C_BOLD}${C_GREEN}   🎉 DOCKER DEPLOYMENT SUCCESSFUL!                              ${C_RESET}"
    echo -e "   App: ${C_BOLD}${APP_NAME}${C_RESET} is ONLINE on port ${C_BOLD}${APP_PORT}${C_RESET} (HTTP ${HTTP_CODE})"
else
    echo -e "${C_BOLD}${C_YELLOW}   ⚠ Container started, still initializing (HTTP: ${HTTP_CODE})       ${C_RESET}"
    echo -e "   Check live logs: ${C_BOLD}$DOCKER_COMPOSE_CMD logs -f starter-template${C_RESET}"
fi
echo -e "   🌐 Local URL : http://127.0.0.1:${APP_PORT}"
echo -e "   🌐 Demo User : demo@example.com / 12345678"
echo -e "   🌐 Admin User: admin@example.com / 12345678"
echo -e "   🌐 1-Click   : http://127.0.0.1:${APP_PORT}/demo"
echo -e "   📋 Logs      : $DOCKER_COMPOSE_CMD logs -f"
echo -e "${C_BOLD}${C_GREEN}=================================================================${C_RESET}\n"
