#!/usr/bin/env bash
set -euo pipefail

REGISTRY="192.168.1.250:5000"
STACK_NAME="hal"
COMPOSE_FILE="docker-compose.yml"

echo "======================================"
echo " HAL V4 SWARM STARTUP PIPELINE"
echo "======================================"

# ----------------------------
# 1. Preconditions check
# ----------------------------

echo "[1/7] Checking Docker Swarm status..."

if ! docker info | grep -q "Swarm: active"; then
  echo "ERROR: Swarm is not active"
  exit 1
fi

echo "Swarm OK"

# ----------------------------
# 2. Build images
# ----------------------------

echo "[2/7] Building images..."

IMAGES=(
  "hal-ps"
  "hal-ppo-learner"
  "hal-ppo-actor"
  "hal-mesh"
  "hal-gateway"
  "hal-gpu"
  "hal-rag"
)

for img in "${IMAGES[@]}"; do
  echo "Building $img..."
  docker build -t "${img}:latest" .
done

# ----------------------------
# 3. Tag + push
# ----------------------------

echo "[3/7] Tagging & pushing to registry..."

for img in "${IMAGES[@]}"; do
  docker tag "${img}:latest" "${REGISTRY}/${img}:latest"
  docker push "${REGISTRY}/${img}:latest"
done

# ----------------------------
# 4. Clean old stack
# ----------------------------

echo "[4/7] Removing existing stack (if any)..."

docker stack rm "$STACK_NAME" || true

echo "Waiting for services to drain..."
sleep 10

# ----------------------------
# 5. Validate compose
# ----------------------------

echo "[5/7] Validating docker-compose..."

docker compose -f "$COMPOSE_FILE" config > /dev/null

echo "Compose valid"

# ----------------------------
# 6. Deploy stack
# ----------------------------

echo "[6/7] Deploying HAL stack..."

docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"

# ----------------------------
# 7. Wait for stabilization
# ----------------------------

echo "[7/7] Waiting for services to stabilize..."

sleep 15

echo ""
echo "Service status:"
docker service ls

echo ""
echo "PS health check:"
docker service logs "$STACK_NAME"_ps --tail 20 || true

echo ""
echo "Actor status:"
docker service logs "$STACK_NAME"_ppo-actor --tail 20 || true

echo ""
echo "======================================"
echo " HAL V4 STACK DEPLOYMENT COMPLETE"
echo "======================================"
