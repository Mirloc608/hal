#!/usr/bin/env bash
set -euo pipefail

SOURCE="hal@ai-srv-node2"
TARGETS=("hal@ai-srv-node1" "hal@ai-srv")

echo "[SYNC] Collecting image list from ${SOURCE}..."
IMAGES=$(ssh "$SOURCE" "docker images --format '{{.Repository}}:{{.Tag}}'")

for IMG in $IMAGES; do
  echo "[SYNC] Syncing image: $IMG"
  for NODE in "${TARGETS[@]}"; do
    echo "  → $NODE"
# shellcheck disable=SC2029
    ssh "$SOURCE" "docker save \\" | ssh "$NODE" docker load || echo "  WARN: failed for $NODE on $IMG"
  done
done

echo "[SYNC] Image sync complete."
