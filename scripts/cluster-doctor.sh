#!/usr/bin/env bash
set -euo pipefail

TAG=$(cat /opt/hal/VERSION 2>/dev/null || echo "unknown")
echo -e "HAL Version: $TAG"

RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"; NC="\033[0m"

banner() {
  echo -e "\n${BLUE}=== $1 ===${NC}"
}

ok()   { echo -e "${GREEN}✔ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
err()  { echo -e "${RED}✖ $1${NC}"; }

banner "HAL Cluster Doctor"

# ---------------------------------------------------------
# 1. Swarm Status
# ---------------------------------------------------------
banner "1. Swarm Status"
docker info | grep -E "Swarm:|Is Manager" || true

# ---------------------------------------------------------
# 2. Node Health
# ---------------------------------------------------------
banner "2. Node Health"
docker node ls

# ---------------------------------------------------------
# 3. Overlay Networks
# ---------------------------------------------------------
banner "3. Overlay Networks"
if docker network ls | grep -q "hal-net"; then
  ok "HAL overlay networks present"
else
  err "HAL overlay networks missing"
fi

# ---------------------------------------------------------
# 4. Container Health
# ---------------------------------------------------------
banner "4. Container Health"
docker ps --format '{{.Names}} {{.Status}}'

# ---------------------------------------------------------
# 5. Zombie Containers
# ---------------------------------------------------------
banner "5. Zombie Containers"
Z=$(docker ps -a --format '{{.Names}}' | grep -E '^hal-' || true)
if [ -z "$Z" ]; then ok "No zombies"; else warn "Zombies detected:"; echo "$Z"; fi

# ---------------------------------------------------------
# 6. Port Conflicts
# ---------------------------------------------------------
banner "6. Port Conflicts"
PORTS=$(ss -tulpn | awk '{print $5}' | cut -d: -f2 | sort -n | uniq)
CONFLICTS=$(echo "$PORTS" | grep -E '8080|8081|8085|3000|3001|6333|9000' || true)
if [ -z "$CONFLICTS" ]; then ok "No HAL port conflicts"; else warn "Conflicting ports:"; echo "$CONFLICTS"; fi

# ---------------------------------------------------------
# 7. Metrics Endpoints
# ---------------------------------------------------------
banner "7. Metrics Endpoints"
for svc in router planner gpu-health; do
  if curl -sf "http://localhost:8080/metrics" >/dev/null 2>&1; then
    ok "$svc metrics reachable"
  else
    warn "$svc metrics unreachable"
  fi
done

# ---------------------------------------------------------
# 8. Prometheus & Grafana
# ---------------------------------------------------------
banner "8. Prometheus & Grafana"
curl -sf http://localhost:9090/-/ready >/dev/null && ok "Prometheus ready" || err "Prometheus not ready"
curl -sf http://localhost:3001/login >/dev/null && ok "Grafana reachable" || err "Grafana unreachable"

# ---------------------------------------------------------
# 9. GPU Health
# ---------------------------------------------------------
banner "9. GPU Health"
if docker ps | grep -q "gpu-health"; then
  curl -sf http://localhost:8085/health && ok "GPU health OK" || warn "GPU health endpoint failed"
else
  warn "GPU health container not running"
fi

# ---------------------------------------------------------
# 10. Disk + RAM + Load
# ---------------------------------------------------------
banner "10. Disk / RAM / Load"
df -h /
free -h
uptime

# ---------------------------------------------------------
# 11. Overlay Connectivity Test
# ---------------------------------------------------------
banner "11. Overlay Connectivity"
for node in ai-srv ai-srv-node1 ai-srv-node2; do
  ssh "$node" "ping -c1 ai-srv >/dev/null 2>&1" \
    && ok "$node can reach ai-srv" \
    || warn "$node cannot reach ai-srv"
done

# ---------------------------------------------------------
# 12. Tag Drift Test
# ---------------------------------------------------------
echo ""
echo "=== Tag Drift Check ==="
for svc in hal-router hal-node1 hal-node2 hal-planner; do
    RUNNING=$(docker service inspect --format '{{index .Spec.TaskTemplate.ContainerSpec.Image}}' hal_${svc} 2>/dev/null || echo "none")
    if [[ "$RUNNING" == *"$TAG" ]]; then
        echo "✔ $svc matches tag $TAG"
    else
        echo "⚠ $svc drift: running $RUNNING but VERSION=$TAG"
    fi
done


banner "HAL Cluster Doctor Complete"
