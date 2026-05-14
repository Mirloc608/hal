#!/usr/bin/env bash
set -euo pipefail

# engines first, router last
NODES=("ai-srv-node2" "ai-srv-node1" "ai-srv")

declare -A COMPOSE_PATHS=(
  ["ai-srv"]="/opt/hal/docker/ai-srv"
  ["ai-srv-node1"]="/opt/hal/docker/node1"
  ["ai-srv-node2"]="/opt/hal/docker/node2"
)

health_check() {
  local node="$1"
  echo "[$node] Health check..."
  ssh "hal@$node" "curl -fsS http://localhost:8000/health >/dev/null" \
    && echo "[$node] HEALTHY" \
    || { echo "[$node] UNHEALTHY"; return 1; }
}

for NODE in "${NODES[@]}"; do
  PATH_DIR="${COMPOSE_PATHS[$NODE]}"
  echo "=== Rolling upgrade on $NODE ==="

  ssh "hal@$NODE" "cd $PATH_DIR && docker compose up -d --build --force-recreate"

  for i in {1..10}; do
    if health_check "$NODE"; then
      break
    fi
    echo "[$NODE] waiting for health... ($i/10)"
    sleep 5
  done
done

echo "Rolling upgrade complete."
