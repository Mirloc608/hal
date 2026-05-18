#!/bin/bash

set -e

echo "============================="
echo " HAL SWARM DEPLOYMENT"
echo "============================="

echo "[1] Removing existing stack..."
docker stack rm hal || true

echo "[2] Waiting for drain..."
sleep 15

echo "[3] Deploying stack..."
docker stack deploy -c /srv/hal/docker-compose.yml hal

echo "[4] Waiting for stabilization..."
sleep 20

echo "[5] Service status:"
docker service ls | grep hal

echo "DEPLOY COMPLETE"
