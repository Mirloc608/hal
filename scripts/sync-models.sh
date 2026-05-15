#!/usr/bin/env bash
set -euo pipefail

WATCH_DIR="/srv/hal/models"
NODES=( "ai-srv-node1" "ai-srv-node2" )

echo "[HAL] Model sync service started. Watching ${WATCH_DIR}"

# Require inotifywait (inotify-tools) for efficient watching
if ! command -v inotifywait >/dev/null 2>&1; then
  echo "[WARN] inotifywait not found; performing one-time sync and exiting."
  for NODE in "${NODES[@]}"; do
    rsync -az --delete "${WATCH_DIR}/" "${NODE}":"${WATCH_DIR}/" || echo "  WARN: rsync failed for ${NODE}"
    ssh -n "${NODE}" "docker exec hal-ollama ollama reload" || echo "  WARN: reload failed on ${NODE}"
  done
  exit 0
fi

inotifywait -m -r -e create,modify,delete,move "${WATCH_DIR}" | while read -r path action file; do
  echo "[HAL] Detected ${action} on ${path}/${file}"
  for NODE in "${NODES[@]}"; do
    rsync -az --delete "${WATCH_DIR}/" "${NODE}":"${WATCH_DIR}/" || echo "  WARN: rsync failed for ${NODE}"
    ssh -n "${NODE}" "docker exec hal-ollama ollama reload" || echo "  WARN: reload failed on ${NODE}"
  done
  echo "[HAL] Sync complete."
done
