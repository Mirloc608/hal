#!/usr/bin/env bash
set -euo pipefail

# Usage: system-reset.sh --yes [--dry-run|-n] [--verbose|-v]

DOCKER_CMD=${DOCKER_CMD:-docker}
CONFIRM=0
DRY_RUN=0
VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --yes) CONFIRM=1; shift ;;
    --dry-run|-n) DRY_RUN=1; shift ;;
    --verbose|-v) VERBOSE=1; shift ;;
    -h|--help) echo "Usage: system-reset.sh --yes [--dry-run|-n] [--verbose|-v]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

if [ "$CONFIRM" -ne 1 ] && [ "${RESET_CONFIRM:-no}" != "yes" ]; then
  echo "Destructive: provide --yes or set RESET_CONFIRM=yes"
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: would remove stacks and volumes"
fi

# After parsing flags
if [ "${VERBOSE:-0}" -eq 1 ]; then
  echo "VERBOSE: DOCKER_CMD=${DOCKER_CMD}"
fi

echo "Performing full system reset"
for s in hal router node1 node2 ke planner tools; do
  echo "  - Removing stack: $s"
  $DOCKER_CMD stack rm "$s" || true
done

sleep 5

for v in postgres_ke_data qdrant_ke_data neo4j_ke_data planner_db_data; do
  echo "  - Removing volume: $v"
  $DOCKER_CMD volume rm "$v" || true
done

echo "✔ System reset complete"
