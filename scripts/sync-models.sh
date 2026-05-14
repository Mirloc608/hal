#!/bin/bash

WATCH_DIR="/srv/hal/models"
NODES=("ai-srv-node1" "ai-srv-node2")

echo "[HAL] Model sync service started. Watching $WATCH_DIR"

inotifywait -m -r -e create,modify,delete,move "$WATCH_DIR" | while read path action file; do
    echo "[HAL] Change detected: $file ($action)"

    for NODE in "${NODES[@]}"; do
        echo "[HAL] Syncing to $NODE..."
        rsync -az --delete /srv/hal/models/ $NODE:/srv/hal/models/

        echo "[HAL] Reloading Ollama on $NODE..."
        ssh $NODE "docker exec hal-ollama ollama reload"
    done

    echo "[HAL] Sync complete."
done

