#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------

NODE1_DIR="/opt/hal/docker/node1"
NODE2_DIR="/opt/hal/docker/node2"

STACK_NODE1="/opt/hal/stacks/node1.yml"
STACK_NODE2="/opt/hal/stacks/node2.yml"

SYNC_SCRIPT="/opt/hal/cluster-image-sync.sh"

ROUTER_CONTAINER="hal-router"

# ------------------------------------------------------------
log() {
  echo "[cluster-deploy] $*" >&2
}

# ------------------------------------------------------------
# BUILD IMAGES
# ------------------------------------------------------------

build_images() {
  log "Building node1 images..."
  docker build -t localhost/node1-rag-node1:latest     -f "$NODE1_DIR/Dockerfile.rag"     "$NODE1_DIR"
  docker build -t localhost/node1-mcp-fs-node1:latest  -f "$NODE1_DIR/Dockerfile.mcp-fs"  "$NODE1_DIR"
  docker build -t localhost/node1-health-node1:latest  -f "$NODE1_DIR/Dockerfile.health"  "$NODE1_DIR"

  log "Building node2 images..."
  docker build -t localhost/node2-rag-node2:latest     -f "$NODE2_DIR/Dockerfile.rag"     "$NODE2_DIR"
  docker build -t localhost/node2-mcp-fs-node2:latest  -f "$NODE2_DIR/Dockerfile.mcp-fs"  "$NODE2_DIR"
  docker build -t localhost/node2-health-node2:latest  -f "$NODE2_DIR/Dockerfile.health"  "$NODE2_DIR"
}

# ------------------------------------------------------------
# SYNC IMAGES TO NODE1 + NODE2
# ------------------------------------------------------------

sync_images() {
  log "Running cluster-image-sync.sh..."
  "$SYNC_SCRIPT"
}

# ------------------------------------------------------------
# DEPLOY STACKS
# ------------------------------------------------------------

deploy_stacks() {
  log "Deploying node1 stack..."
  docker stack deploy -c "$STACK_NODE1" node1

  log "Deploying node2 stack..."
  docker stack deploy -c "$STACK_NODE2" node2
}

# ------------------------------------------------------------
# VERIFY OVERLAY NETWORK
# ------------------------------------------------------------

verify_overlay() {
  log "Checking overlay network attachment..."
  docker network inspect hal_cluster_net | grep Containers -A20 || true
}

# ------------------------------------------------------------
# VERIFY DNS FROM ROUTER
# ------------------------------------------------------------

verify_dns() {
  log "Testing DNS + API from router..."

  docker exec -it "$ROUTER_CONTAINER" curl -s http://ollama-node1:11434/api/version || log "node1 unreachable"
  docker exec -it "$ROUTER_CONTAINER" curl -s http://ollama-node2:11434/api/version || log "node2 unreachable"
}

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------

log "Starting full cluster deploy..."

build_images
sync_images
deploy_stacks

sleep 5

verify_overlay
verify_dns

log "Cluster deploy complete."
