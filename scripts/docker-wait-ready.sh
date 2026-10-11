#!/usr/bin/env bash

# Shared Docker deploy/update health gates for SvelteKitStarter.
set -euo pipefail
if [ "$#" -eq 0 ]; then echo "Compose command required." >&2; exit 1; fi
DOCKER_COMPOSE_CMD=("$@")
for attempt in $(seq 1 60); do
    READY=true
    for service in starter-template; do
        container_id=$("${DOCKER_COMPOSE_CMD[@]}" ps -q "$service")
        if [ -z "$container_id" ]; then READY=false; break; fi
        state=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$container_id")
        if [ "$state" != healthy ]; then READY=false; fi
    done
    if [ "$READY" = true ]; then
        echo "Docker services ready: starter-template healthy."
        exit 0
    fi
    sleep 2
done
echo "Services did not become ready within 120 seconds. Inspect Compose logs." >&2
exit 1
