#!/bin/bash

set -e

echo "======================================"
echo " HAL V4.1 CORRECTNESS BOOT"
echo "======================================"

REGISTRY="192.168.1.250:5000"
STACK="hal"

echo "[1] Validating swarm..."
docker info | grep -i swarm || exit 1

echo "[2] Building images..."
SERVICES="ps ppo-actor ppo-learner mesh gateway gpu rag"

for s in $SERVICES; do
  echo "Building $s..."
  docker build -t $REGISTRY/hal-$s:latest .
done

echo "[3] Pushing images..."
for s in $SERVICES; do
  docker push $REGISTRY/hal-$s:latest
done

echo "[4] Redeploy stack..."
docker stack rm $STACK || true
sleep 10

docker stack deploy -c docker-compose.yml $STACK

echo "[5] Waiting for PS health..."
sleep 10

for i in {1..30}; do
  if curl -s http://localhost:9000/health >/dev/null; then
    echo "PS HEALTH OK"
    break
  fi
  echo "waiting for PS..."
  sleep 2
done

echo "======================================"
echo " V4.1 DEPLOYMENT COMPLETE"
echo "======================================"
