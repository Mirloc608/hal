#!/usr/bin/env bash
set -euo pipefail

# -------- config --------
CTRL_HOST="ai-srv"
NODE1_HOST="ai-srv-node1"
NODE2_HOST="ai-srv-node2"

REMOTE_DIR="/opt/hal/docker"

BLUE="\033[1;34m"
# shellcheck disable=SC2034
GREEN="\033[1;32m"
# shellcheck disable=SC2034
# shellcheck disable=SC2034
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# -------- helpers --------
log() {
  printf "%b[%s]%b %s\n" "$BLUE" "$1" "$RESET" "$2"
}

run_remote() {
  local host="$1"
  local cmd="$2"
  log "$host" "Running: $cmd"
  ssh "$host" "cd '$REMOTE_DIR' && $cmd"
}

# -------- actions --------
do_rebuild() {
  log "CLUSTER" "Rebuilding all nodes (router + node1 + node2)..."
  run_remote "$NODE1_HOST" "make node1-rebuild"
  run_remote "$NODE2_HOST" "make node2-rebuild"
  run_remote "$CTRL_HOST"  "make router-rebuild"
  printf "%b[CLUSTER]%b Rebuild complete\n" "$GREEN" "$RESET"
}

do_up() {
  log "CLUSTER" "Starting all nodes..."
  run_remote "$NODE1_HOST" "make node1-up"
  run_remote "$NODE2_HOST" "make node2-up"
  run_remote "$CTRL_HOST"  "make router-up"
  printf "%b[CLUSTER]%b All nodes up\n" "$GREEN" "$RESET"
}

do_down() {
  log "CLUSTER" "Stopping all nodes..."
  run_remote "$CTRL_HOST"  "make router-down"
  run_remote "$NODE1_HOST" "make node1-down"
  run_remote "$NODE2_HOST" "make node2-down"
  printf "%b[CLUSTER]%b All nodes down\n" "$GREEN" "$RESET"
}

do_status() {
  log "CLUSTER" "Status (docker ps on each host)..."
  run_remote "$NODE1_HOST" "docker ps --format 'table {{.Names}}\t{{.Status}}'"
  run_remote "$NODE2_HOST" "docker ps --format 'table {{.Names}}\t{{.Status}}'"
  run_remote "$CTRL_HOST"  "docker ps --format 'table {{.Names}}\t{{.Status}}'"
}

usage() {
  cat <<EOF
Usage: $0 [command]

Commands:
  rebuild   Rebuild router + node1 + node2 (no cache) and start them
  up        Start all nodes
  down      Stop all nodes
  status    Show docker ps on all nodes
EOF
}

# -------- main --------
cmd="${1:-}"

case "$cmd" in
  rebuild) do_rebuild ;;
  up)      do_up ;;
  down)    do_down ;;
  status)  do_status ;;
  *)       usage; exit 1 ;;
esac
