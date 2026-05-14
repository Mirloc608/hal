#!/usr/bin/env bash
set -euo pipefail

declare -A SERVICES

SERVICES["ai-srv"]="hal-openwebui hal-router hal-rag hal-mcp-fs hal-ollama hal-traefik hal-prometheus hal-grafana hal-qdrant hal-node-exporter"
SERVICES["ai-srv-node1"]="hal-ollama-node1 hal-rag-node1 hal-mcp-fs-node1 hal-health-node1 hal-node1-node-exporter"
SERVICES["ai-srv-node2"]="hal-ollama-node2 hal-rag-node2 hal-mcp-fs-node2 hal-health-node2 hal-node2-node-exporter"

NODES=("ai-srv" "ai-srv-node1" "ai-srv-node2")

echo "Tailing logs (Ctrl+C to stop)..."

for NODE in "${NODES[@]}"; do
  for SVC in ${SERVICES[$NODE]}; do
    ssh "hal@$NODE" "docker logs -f $SVC 2>&1" | sed -u "s/^/[$NODE][$SVC] /" &
  done
done

wait
