#!/usr/bin/env bash
set -euo pipefail

NODES=("ai-srv" "ai-srv-node1" "ai-srv-node2")

declare -A COMPOSE_PATHS=(
  ["ai-srv"]="/opt/hal/docker/ai-srv"
  ["ai-srv-node1"]="/opt/hal/docker/node1"
  ["ai-srv-node2"]="/opt/hal/docker/node2"
)

action="${1:-}"

if [[ -z "$action" ]]; then
  echo "Usage: $0 {start|stop|rebuild|status}"
  exit 1
fi

for NODE in "${NODES[@]}"; do
  PATH_DIR="${COMPOSE_PATHS[$NODE]}"
  echo "[$NODE] $action"

  case "$action" in
    start)
      ssh "hal@$NODE" "cd $PATH_DIR && docker compose up -d"
      ;;
    stop)
      ssh "hal@$NODE" "cd $PATH_DIR && docker compose down"
      ;;
    rebuild)
      ssh "hal@$NODE" "cd $PATH_DIR && docker compose up -d --build --force-recreate"
      ;;
    status)
      ssh "hal@$NODE" "cd $PATH_DIR && docker compose ps"
      ;;
    *)
      echo "Unknown action: $action"
      exit 1
      ;;
  esac
done
