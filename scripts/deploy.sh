#!/usr/bin/env bash

# ==============================================================================
# 🚀 SvelteKit Starter Template - Production Automated Deployment Script
# ==============================================================================
# Usage on VPS:
#   git clone git@github.com-github-thanhlam2020:LamVT2020/sveltekit-starter-template.git
#   cd sveltekit-starter-template
#   ./scripts/deploy.sh (or: npm run deploy)
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
echo "   🚀 SVELTEKIT STARTER - AUTOMATED PRODUCTION DEPLOYMENT       "
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
    echo -e "${C_RED}❌ Error: Node.js is not installed on this server!${C_RESET}"
    echo "  Please install Node.js (recommended version >= 18 or 20 LTS)."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${C_RED}❌ Error: npm is not installed on this server!${C_RESET}"
    exit 1
fi

NODE_VERSION=$(node -v)
NPM_VERSION=$(npm -v)
echo -e "${C_GREEN}✔ Node.js:${C_RESET} $NODE_VERSION | ${C_GREEN}npm:${C_RESET} $NPM_VERSION"

# Helper function to read variable value from .env
get_env_val() {
    local key="$1"
    if [ -f ".env" ]; then
        (grep -E "^[[:space:]]*${key}=" .env 2>/dev/null || true) | tail -n 1 | cut -d '=' -f2- | sed -e 's/^[[:space:]]*["'"'"']//' -e 's/["'"'"'][[:space:]]*$//' -e 's/[[:space:]]*#.*$//'
    fi
}

# Helper function to generate cryptographically secure random string
generate_secret() {
    if command -v openssl &>/dev/null; then
        openssl rand -hex 32
    else
        node -e "console.log(require('crypto').randomBytes(32).toString('hex'))" 2>/dev/null || date +%s%N | sha256sum | head -c 64
    fi
}

# 2. Process .env configuration & perform configuration audit
echo -e "\n${C_CYAN}⚙️ Step 1/7: Inspecting and standardizing configuration (.env)...${C_RESET}"

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo -e "${C_YELLOW}ℹ File .env not found. Automatically copying from .env.example...${C_RESET}"
        cp .env.example .env
    else
        echo -e "${C_RED}❌ Error: Neither .env nor .env.example was found!${C_RESET}"
        exit 1
    fi
fi

# Ensure PORT is defined (default 3000 for sveltekit-starter-template)
APP_PORT="$(get_env_val PORT)"
if [ -z "$APP_PORT" ]; then
    APP_PORT="3000"
    echo "PORT=3000" >> .env
    echo -e "${C_GREEN}✔ Appended PORT=3000 to .env${C_RESET}"
fi

# Auto-generate AUTH_SECRET if placeholder or empty
AUTH_SECRET_VAL="$(get_env_val AUTH_SECRET)"
if [ -z "$AUTH_SECRET_VAL" ] || [[ "$AUTH_SECRET_VAL" == *"change-this"* ]] || [[ "$AUTH_SECRET_VAL" == *"starter-template"* ]]; then
    NEW_SECRET="$(generate_secret)"
    if grep -q "^[[:space:]]*AUTH_SECRET=" .env; then
        sed -i.bak "s|^[[:space:]]*AUTH_SECRET=.*|AUTH_SECRET=\"$NEW_SECRET\"|" .env && rm -f .env.bak
    else
        echo "AUTH_SECRET=\"$NEW_SECRET\"" >> .env
    fi
    echo -e "${C_GREEN}✔ Generated secure random AUTH_SECRET${C_RESET}"
fi

# --- CONFIGURATION AUDIT ---
echo -e "\n${C_BOLD}${C_MAGENTA}📋 CONFIGURATION AUDIT REPORT:${C_RESET}"

MISSING_REQUIRED=0
MISSING_OPTIONAL=0
MISSING_KEYS=()

audit_config() {
    local key="$1"
    local level="$2"     # "REQUIRED" | "OPTIONAL"
    local desc="$3"
    local val
    val="$(get_env_val "$key")"

    local is_empty=0
    if [ -z "$val" ]; then
        is_empty=1
    elif [[ "$val" == *"change"* ]] || [[ "$val" == *"your_"* ]] || [[ "$val" == *"TODO"* ]]; then
        is_empty=1
    fi

    if [ "$is_empty" -eq 0 ]; then
        local masked_val="$val"
        if [ ${#val} -gt 24 ]; then
            masked_val="${val:0:8}...${val: -4}"
        fi
        echo -e "  ${C_GREEN}✔ [CONFIGURED]${C_RESET} ${C_BOLD}${key}${C_RESET} = ${masked_val} (${desc})"
    else
        if [ "$level" = "REQUIRED" ]; then
            echo -e "  ${C_RED}✖ [REQUIRED]${C_RESET} ${C_BOLD}${key}${C_RESET} - ${desc}"
            MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
            MISSING_KEYS+=("$key ($desc)")
        else
            echo -e "  ${C_YELLOW}⚠ [OPTIONAL]${C_RESET} ${C_BOLD}${key}${C_RESET} - ${desc}"
            MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
            MISSING_KEYS+=("$key (Optional: $desc)")
        fi
    fi
}

echo -e "${C_CYAN}▶ 1. Runtime & System:${C_RESET}"
audit_config "PORT" "REQUIRED" "Web service port (Target: $APP_PORT)"
audit_config "DATABASE_URL" "REQUIRED" "SQLite database connection string"
audit_config "APP_ORIGIN" "OPTIONAL" "Application URL (e.g. http://vps-ip:3000 or https://yourdomain.com)"

echo -e "${C_CYAN}▶ 2. Security & Authentication:${C_RESET}"
audit_config "AUTH_SECRET" "REQUIRED" "Auth encryption secret"
audit_config "ENABLE_DEMO_LOGIN" "OPTIONAL" "Enable demo quick login buttons (true/false, default: true)"

echo -e "${C_CYAN}▶ 3. Artificial Intelligence (AI Engine):${C_RESET}"
audit_config "AI_PROVIDER" "REQUIRED" "Primary AI Provider (gemini)"
audit_config "AI_MODEL" "REQUIRED" "AI Model identifier (gemini-2.0-flash)"
audit_config "GEMINI_API_KEY" "OPTIONAL" "Google Gemini API Key"

echo -e "${C_CYAN}▶ 4. Monitoring & Telemetry:${C_RESET}"
audit_config "GOOGLE_ANALYTICS_ID" "OPTIONAL" "Google Analytics Tracking ID"

if [ "$MISSING_REQUIRED" -gt 0 ] || [ "$MISSING_OPTIONAL" -gt 0 ]; then
    echo -e "\n${C_YELLOW}┌────────────────────────────────────────────────────────────────────────┐${C_RESET}"
    echo -e "${C_YELLOW}│ 💡 CONFIGURATION GUIDE:                                                │${C_RESET}"
    echo -e "${C_YELLOW}│ To update missing credentials, edit your environment file:             │${C_RESET}"
    echo -e "${C_YELLOW}│   ${C_BOLD}nano .env${C_RESET}${C_YELLOW}                                                           │${C_RESET}"
    echo -e "${C_YELLOW}│ After saving (Ctrl+O, Enter, Ctrl+X), reload the service with:         │${C_RESET}"
    echo -e "${C_YELLOW}│   ${C_BOLD}pm2 restart ecosystem.config.cjs --update-env${C_RESET}${C_YELLOW}                      │${C_RESET}"
    echo -e "${C_YELLOW}└────────────────────────────────────────────────────────────────────────┘${C_RESET}"
fi

# 3. Create required data folders and backup database if present
echo -e "\n${C_CYAN}📦 Step 2/7: Preparing directories and snapshots...${C_RESET}"
mkdir -p data logs backups

if [ -f "prisma/dev.db" ] || [ -f "dev.db" ]; then
    if grep -q '"backup"' package.json 2>/dev/null; then
        echo -e "${C_CYAN}  Creating database backup snapshot...${C_RESET}"
        npm run backup 2>/dev/null || true
    fi
fi

# 4. Pull latest git commits if running inside a cloned repository
if [ -d ".git" ]; then
    echo -e "\n${C_CYAN}📥 Step 3/7: Checking for Git updates...${C_RESET}"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git pull origin "$CURRENT_BRANCH" 2>/dev/null || echo -e "${C_YELLOW}  Skipped git pull (fresh clone or local modifications)${C_RESET}"
fi

# 5. Install production dependencies
echo -e "\n${C_CYAN}📦 Step 4/7: Installing npm dependencies...${C_RESET}"
npm install --no-audit --no-fund

# 6. Synchronize Prisma Database & seed initial accounts
echo -e "\n${C_CYAN}🗄️ Step 5/7: Synchronizing Prisma schema and initializing users...${C_RESET}"
npx prisma generate
npx prisma db push --skip-generate

if grep -q '"seed:users"' package.json 2>/dev/null; then
    echo -e "${C_CYAN}  Seeding administrative / demo accounts...${C_RESET}"
    npm run seed:users 2>/dev/null || true
fi

# 7. Build SvelteKit production bundle
echo -e "\n${C_CYAN}🛠️ Step 6/7: Building SvelteKit production bundle...${C_RESET}"
npm run build

if [ ! -f "build/index.js" ]; then
    echo -e "${C_RED}❌ Error: Build failed, build/index.js was not generated!${C_RESET}"
    exit 1
fi
echo -e "${C_GREEN}✔ Build successful (build/index.js ready)${C_RESET}"

# 8. Manage PM2 runtime processes
echo -e "\n${C_CYAN}⚡ Step 7/7: Starting / Reloading services via PM2...${C_RESET}"
PM2_CMD="pm2"
if ! command -v pm2 &> /dev/null; then
    echo -e "${C_YELLOW}⚠ PM2 not installed globally. Attempting installation via npm...${C_RESET}"
    npm install -g pm2 2>/dev/null || true
    if ! command -v pm2 &> /dev/null; then
        PM2_CMD="npx pm2"
    fi
fi

if [ -f "ecosystem.config.cjs" ]; then
    $PM2_CMD restart ecosystem.config.cjs --update-env || $PM2_CMD startOrRestart ecosystem.config.cjs --env production --update-env
    $PM2_CMD save 2>/dev/null || true
    echo -e "${C_GREEN}✔ PM2 process state updated successfully.${C_RESET}"
else
    echo -e "${C_RED}❌ Error: ecosystem.config.cjs not found!${C_RESET}"
    exit 1
fi

# 9. Health check verification & final summary
echo -e "\n${C_CYAN}🔍 Verifying service status on port ${APP_PORT}...${C_RESET}"
sleep 3

HEALTH_CHECK_URL="http://127.0.0.1:${APP_PORT}/"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" 2>/dev/null || echo "000")

echo -e "\n${C_BOLD}${C_GREEN}=================================================================${C_RESET}"
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "307" ]; then
    echo -e "${C_BOLD}${C_GREEN}   🎉 DEPLOYMENT SUCCESSFUL!                                     ${C_RESET}"
    echo -e "   App: ${C_BOLD}SvelteKit Starter${C_RESET} is ONLINE on port: ${C_BOLD}${APP_PORT}${C_RESET} (HTTP ${HTTP_STATUS})"
else
    echo -e "${C_BOLD}${C_YELLOW}   ⚠ DEPLOYMENT COMPLETED (HTTP Status: ${HTTP_STATUS})                    ${C_RESET}"
    echo -e "   Inspect runtime logs with: ${C_BOLD}pm2 logs sveltekit-starter-template --lines 50${C_RESET}"
fi
echo -e "   🌐 Local URL : http://127.0.0.1:${APP_PORT}"
echo -e "   🌐 Public URL: http://<VPS_IP>:${APP_PORT}"
echo -e "${C_BOLD}${C_GREEN}=================================================================${C_RESET}"

if [ "${#MISSING_KEYS[@]}" -gt 0 ]; then
    echo -e "\n${C_YELLOW}📌 PENDING CONFIGURATIONS TO COMPLETE IN .env:${C_RESET}"
    for item in "${MISSING_KEYS[@]}"; do
        echo -e "  • ${item}"
    done
    echo -e "\n${C_CYAN}👉 Run: ${C_BOLD}nano .env${C_RESET}${C_CYAN} to update, then re-run deploy or: ${C_BOLD}pm2 restart ecosystem.config.cjs --update-env${C_RESET}\n"
fi
