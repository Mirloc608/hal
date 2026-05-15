#!/usr/bin/env bash
set -euo pipefail

echo "Cluster doctor starting..."

# 1. Docker nodes
echo "→ docker node ls"
docker node ls || { echo "docker node ls failed"; exit 2; }

# 2. Overlay network check
NET="hal-overlay"
if docker network ls --filter name=^${NET}$$ --format '{{.Name}}' | grep -q "^${NET}$$"; then
  echo "→ overlay network ${NET} exists"
else
  echo "✖ overlay network ${NET} missing"
  exit 2
fi

# 3. Manager quorum
MANAGER_COUNT=$(docker node ls --filter role=manager --format '{{.ID}}' | wc -l)
if [ "$MANAGER_COUNT" -ge 1 ]; then
  echo "→ manager count: $MANAGER_COUNT"
else
  echo "✖ no manager detected"
  exit 2
fi

# 4. Disk and memory on manager
echo "→ checking manager disk and memory"
df -h / | awk 'NR==1 || $5+0 < 90 {print}' || true
free -m || true

# 5. Docker daemon health
echo "→ docker info"
docker info --format '{{json .}}' >/dev/null || { echo "✖ docker info failed"; exit 2; }

echo "Cluster doctor checks passed"
