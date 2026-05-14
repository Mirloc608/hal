#!/usr/bin/env bash
set -euo pipefail

echo "==============================================="
echo " HAL v2 — Docker Swarm Port Scanner"
echo "==============================================="

echo
echo "[1] Listing all Swarm services with published ports..."
echo

docker service ls --format "table {{.Name}}\t{{.Ports}}"

echo
echo "-----------------------------------------------"
echo "[2] Extracting all published ports..."
echo

docker service ls --format "{{.Ports}}" \
  | grep -oE '[0-9]+(?=/tcp)' \
  | sort -n \
  | uniq \
  | tee /tmp/hal_used_ports.txt

echo
echo "-----------------------------------------------"
echo "[3] Checking which ports are LISTENING on each node..."
echo

for NODE in ai-srv ai-srv-node1 ai-srv-node2; do
  echo "Node: $NODE"
  ssh "$NODE" "sudo ss -tulpn | grep LISTEN | awk '{print \$5}' | cut -d: -f2 | sort -n | uniq" \
    | sed 's/^/  /'
  echo
done

echo "-----------------------------------------------"
echo "[4] Suggesting SAFE ports (3000–3999 range)..."
echo

USED=$(cat /tmp/hal_used_ports.txt | tr '\n' ' ')
echo "Used ports: $USED"
echo

echo "Safe ports:"
for PORT in $(seq 3000 3999); do
  if ! grep -q "^$PORT$" /tmp/hal_used_ports.txt; then
    echo "  $PORT"
  fi
done | head -n 20

echo
echo "==============================================="
echo " Scan complete."
echo "==============================================="
