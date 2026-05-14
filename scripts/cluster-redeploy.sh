#!/usr/bin/env bash
set -euo pipefail

cd /opt/hal

echo "→ Pruning cluster..."
make cluster-prune || echo "  (prune failed or partial, continuing)"

echo "→ Rebuilding and deploying full HAL cluster..."
make cluster

echo "✔ Full cluster redeploy complete"
