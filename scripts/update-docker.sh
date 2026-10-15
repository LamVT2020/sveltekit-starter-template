#!/usr/bin/env bash

# SvelteKit Starter - Docker Code & Image Update Script
# npm run update:docker
# npm run update:docker -- --no-pull (source uploaded manually)
set -Eeuo pipefail

SKIP_PULL=false
case "${1:-}" in
    "") ;;
    --no-pull) SKIP_PULL=true ;;
    *) echo "Usage: npm run update:docker -- [--no-pull]" >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then echo "Unexpected arguments." >&2; exit 1; fi

# 0. Resolve project working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"
PHASE=preparation
trap 'code=$?; if [ "$code" -ne 0 ]; then echo "Docker update failed during $PHASE. No automatic DB restore or service restart was performed. Inspect the error before retrying." >&2; fi' EXIT

# 1. Resolve Docker Compose command
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD=(docker-compose)
else
    echo "docker compose is not installed." >&2
    exit 1
fi

# 2. Pull latest Git commits. Stop on conflicts or divergence.
if [ "$SKIP_PULL" = false ] && [ -d .git ]; then
    CURRENT_BRANCH=$(git symbolic-ref --quiet --short HEAD)
    git pull --ff-only origin "$CURRENT_BRANCH"
fi
"${DOCKER_COMPOSE_CMD[@]}" config --quiet

# 3. Build first; existing containers keep running if build fails.
echo "Building image before maintenance..."
"${DOCKER_COMPOSE_CMD[@]}" build starter-template
echo "Docker image built successfully."

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

# 4. Snapshot the running web container's actual database and mounted data directory.
# Stream new helper source: the running image need not contain it.
DEPLOY_BACKUP_ID="$(date -u +%Y%m%dT%H%M%S)-$$-${RANDOM}"
echo "Creating verified SQLite snapshot ($DEPLOY_BACKUP_ID)..."
BACKUP_LOCATION=$("${DOCKER_COMPOSE_CMD[@]}" exec -T --user node -e "DEPLOY_BACKUP_ID=$DEPLOY_BACKUP_ID" starter-template node --input-type=module < scripts/docker-db-backup.mjs)
echo "$BACKUP_LOCATION"

# 5. Stop all DB writers gracefully and require schema synchronization to succeed.
echo "Maintenance: stopping web service..."
PHASE=maintenance
"${DOCKER_COMPOSE_CMD[@]}" stop -t 60 starter-template
"${DOCKER_COMPOSE_CMD[@]}" run --rm --no-deps --user node --entrypoint node -e "DEPLOY_BACKUP_ID=$DEPLOY_BACKUP_ID" starter-template scripts/docker-db-backup.mjs --verify
"${DOCKER_COMPOSE_CMD[@]}" run --rm --no-deps --entrypoint /usr/local/bin/docker-entrypoint.sh -e RUN_MIGRATIONS=true -e SEED_USERS=false starter-template true

# Archive verified snapshot to designated host BACKUP_DIR and prune older snapshots
mkdir -p "$HOST_BACKUP_DIR"
STAGING_DB="$HOST_DATA_DIR/.deployment-backups/${DEPLOY_BACKUP_ID}.db"
STAGING_JSON="$HOST_DATA_DIR/.deployment-backups/${DEPLOY_BACKUP_ID}.json"
TARGET_BACKUP_DB="$HOST_BACKUP_DIR/${DEPLOY_BACKUP_ID}.db"
TARGET_BACKUP_JSON="$HOST_BACKUP_DIR/${DEPLOY_BACKUP_ID}.json"

if [ -f "$STAGING_DB" ]; then
    cp -p "$STAGING_DB" "$TARGET_BACKUP_DB"
    if [ -f "$STAGING_JSON" ]; then cp -p "$STAGING_JSON" "$TARGET_BACKUP_JSON" 2>/dev/null || true; fi
    BACKUP_LOCATION="Verified deployment snapshot: $TARGET_BACKUP_DB"
    
    # Prune old backups in target backup dir (retain 5 newest)
    find "$HOST_BACKUP_DIR" -maxdepth 1 -name "*.db" -type f | sort -r | tail -n +6 | while read -r old_snap; do
        rm -f "$old_snap" "${old_snap%.db}.json" 2>/dev/null || true
    done
    # Prune staging backups in .deployment-backups (retain 3 newest)
    find "$HOST_DATA_DIR/.deployment-backups" -maxdepth 1 -name "*.db" -type f | sort -r | tail -n +4 | while read -r old_stage; do
        rm -f "$old_stage" "${old_stage%.db}.json" 2>/dev/null || true
    done
elif [ -d "$HOST_BACKUP_DIR" ]; then
    BACKUP_LOCATION="Verified deployment snapshot: $TARGET_BACKUP_DB"
fi

# 6. Recreate with the built image.
PHASE=startup
"${DOCKER_COMPOSE_CMD[@]}" up -d --no-build --force-recreate

# 7. Health check verification: fail instead of printing false success.
PHASE=health-check
bash scripts/docker-wait-ready.sh "${DOCKER_COMPOSE_CMD[@]}"
echo "Docker update successful."
echo "$BACKUP_LOCATION"
echo "Inspect web logs: ${DOCKER_COMPOSE_CMD[*]} logs --tail 100 starter-template"
