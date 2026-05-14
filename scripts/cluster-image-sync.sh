#!/bin/bash
set -e

NODES=("ai-srv-node1" "ai-srv-node2")

echo "[sync] Auto-detecting latest HAL images..."

# Detect latest images by prefix
LATEST_ROUTER=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "localhost/hal-router" | sort -r | head -n 1)
LATEST_NODE1=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "localhost/node1" | sort -r | head -n 1)
LATEST_NODE2=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "localhost/node2" | sort -r | head -n 1)

IMAGES=("$LATEST_ROUTER" "$LATEST_NODE1" "$LATEST_NODE2")

echo "[sync] Latest detected:"
printf "  %s\n" "${IMAGES[@]}"

for node in "${NODES[@]}"; do
    echo "[sync] Syncing to $node..."
    for img in "${IMAGES[@]}"; do
        echo "  → $img"
        docker save "$img" | ssh "$node" docker load
    done
done

echo "[sync] Complete."
