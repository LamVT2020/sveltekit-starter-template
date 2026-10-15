#!/usr/bin/env bash

# SvelteKit Starter - Docker Automated Deployment Script (Port 3005)
# npm run deploy:docker deploys the source already present in this checkout.
# Existing stacks use the verified update workflow; preserve data and state first.
set -Eeuo pipefail
if [ "$#" -ne 0 ]; then echo "Usage: npm run deploy:docker" >&2; exit 1; fi

# 0. Resolve project working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"
PHASE=preparation
trap 'code=$?; if [ "$code" -ne 0 ]; then echo "Docker deployment failed during $PHASE. Inspect the error before retrying; no automatic DB restore was performed." >&2; fi' EXIT

# 1. Resolve Docker Compose command
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD=(docker-compose)
else
    echo "docker compose is not installed." >&2
    exit 1
fi

# 2. Preserve an existing .env; link an explicit/external config only if absent.
# Do not copy example secrets, rewrite PORT, override DATA_DIR or chmod storage 777.
if [ ! -f .env ]; then
    if [ -e .env ] || [ -L .env ]; then echo "Existing .env is invalid; refusing to overwrite it." >&2; exit 1; fi
    CONFIG_FILE="${DEPLOY_ENV_FILE:-}"
    if [ -z "$CONFIG_FILE" ]; then
        for candidate in /home/deploy/configs/sveltekit-starter-template/.env /home/deploy/configs/starter-template/.env /home/deploy/config/sveltekit-starter-template/.env /home/deploy/config/starter-template/.env /home/deploy/apps/sveltekit-starter-template/.env /home/deploy/apps/starter-template/.env; do
            if [ -f "$candidate" ]; then CONFIG_FILE="$candidate"; break; fi
        done
    fi
    if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
        echo "Configure a production .env first, or set DEPLOY_ENV_FILE to its path. Example configuration is not deployed automatically." >&2
        exit 1
    fi
    ln -s "$CONFIG_FILE" .env
fi
"${DOCKER_COMPOSE_CMD[@]}" config --quiet

# 3. Existing containers (including stopped ones) must use the update safety gates.
EXISTING_CONTAINERS=$("${DOCKER_COMPOSE_CMD[@]}" ps -a -q)
if [ -n "$EXISTING_CONTAINERS" ]; then
    echo "Existing stack detected; using verified update with the current checkout."
    exec bash scripts/update-docker.sh --no-pull
fi

# 4. Build before changing the DB or starting services.
echo "Building first-deployment image..."
"${DOCKER_COMPOSE_CMD[@]}" build starter-template

# Resolve host DATA_DIR and BACKUP_DIR
PROJECT_NAME="starter-template"
HOST_BACKUP_DIR=""
HOST_DATA_DIR=""
for env_candidate in .env /home/deploy/configs/"$PROJECT_NAME"/.env /home/deploy/apps/"$PROJECT_NAME"/.env; do
    if [ -f "$env_candidate" ]; then
        if [ -z "$HOST_BACKUP_DIR" ] && grep -q '^BACKUP_DIR=' "$env_candidate"; then
            HOST_BACKUP_DIR=$(grep '^BACKUP_DIR=' "$env_candidate" | cut -d '=' -f2- | tr -d '"'\'' ' | head -n1)
        fi
        if [ -z "$HOST_DATA_DIR" ] && grep -q '^DATA_DIR=' "$env_candidate"; then
            HOST_DATA_DIR=$(grep '^DATA_DIR=' "$env_candidate" | cut -d '=' -f2- | tr -d '"'\'' ' | head -n1)
        fi
    fi
done

if [ -z "$HOST_BACKUP_DIR" ]; then
    if [ -d "/home/deploy/backups" ]; then
        HOST_BACKUP_DIR="/home/deploy/backups/$PROJECT_NAME"
    else
        HOST_BACKUP_DIR="$PROJECT_DIR/backups"
    fi
fi

if [ -z "$HOST_DATA_DIR" ]; then
    if [ -d "/home/deploy/data/$PROJECT_NAME" ]; then
        HOST_DATA_DIR="/home/deploy/data/$PROJECT_NAME"
    else
        HOST_DATA_DIR="$PROJECT_DIR/data"
    fi
fi

# 5. The mount can contain an existing DB even without Compose containers.
# Snapshot it before schema synchronization; a truly absent DB is initialized explicitly.
PHASE=database-preparation
DEPLOY_BACKUP_ID="$(date -u +%Y%m%dT%H%M%S)-$$-${RANDOM}"
"${DOCKER_COMPOSE_CMD[@]}" run --rm --no-deps --user node --entrypoint node -e "DEPLOY_BACKUP_ID=$DEPLOY_BACKUP_ID" starter-template scripts/docker-db-backup.mjs --prepare-deploy
"${DOCKER_COMPOSE_CMD[@]}" run --rm --no-deps --entrypoint /usr/local/bin/docker-entrypoint.sh -e RUN_MIGRATIONS=true -e SEED_USERS=false starter-template true

# Archive verified snapshot to designated host BACKUP_DIR if one was prepared
if [ -n "$HOST_DATA_DIR" ] && [ -f "$HOST_DATA_DIR/.deployment-backups/${DEPLOY_BACKUP_ID}.db" ]; then
    mkdir -p "$HOST_BACKUP_DIR"
    cp -p "$HOST_DATA_DIR/.deployment-backups/${DEPLOY_BACKUP_ID}.db" "$HOST_BACKUP_DIR/${DEPLOY_BACKUP_ID}.db"
    if [ -f "$HOST_DATA_DIR/.deployment-backups/${DEPLOY_BACKUP_ID}.json" ]; then
        cp -p "$HOST_DATA_DIR/.deployment-backups/${DEPLOY_BACKUP_ID}.json" "$HOST_BACKUP_DIR/${DEPLOY_BACKUP_ID}.json" 2>/dev/null || true
    fi
fi

# 6. Start only after successful schema synchronization. No forced container deletion.
PHASE=startup
"${DOCKER_COMPOSE_CMD[@]}" up -d --no-build

# 7. Health check verification uses the same checks as updates.
PHASE=health-check
bash scripts/docker-wait-ready.sh "${DOCKER_COMPOSE_CMD[@]}"
echo "Docker deployment successful. User accounts were not seeded."
echo "Inspect web logs: ${DOCKER_COMPOSE_CMD[*]} logs --tail 100 starter-template"
