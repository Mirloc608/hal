#!/usr/bin/env bash
set -euo pipefail

NODES=("ai-srv" "ai-srv-node1" "ai-srv-node2")

echo "=== HAL CLUSTER HEALTH ==="

for NODE in "${NODES[@]}"; do
  echo
  echo "--- $NODE ---"

  echo "[SSH] Checking SSH..."
  ssh -o BatchMode=yes "hal@$NODE" "echo OK" || echo "SSH FAIL"

  echo "[DOCKER] Checking Docker..."
  ssh "hal@$NODE" "docker ps --format '{{.Names}}: {{.Status}}' || echo 'Docker FAIL'"

  echo "[OLLAMA] Checking Ollama API..."
  ssh "hal@$NODE" "curl -fsS http://localhost:11434/api/tags || echo 'Ollama FAIL'"

  echo "[RAG] Checking RAG..."
  ssh "hal@$NODE" "curl -fsS http://localhost:8001/health || echo 'RAG FAIL'"

  echo "[MCP-FS] Checking MCP-FS..."
  ssh "hal@$NODE" "curl -fsS http://localhost:8002/health || echo 'MCP-FS FAIL'"

  echo "[HEALTH] Checking health endpoint..."
  ssh "hal@$NODE" "curl -fsS http://localhost:8000/health || echo 'Health FAIL'"
done

echo
echo "=== CLUSTER HEALTH CHECK COMPLETE ==="
