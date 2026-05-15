#!/usr/bin/env bash
set -euo pipefail

# Orchestrator for OpenWebUI on Docker Swarm
# Usage:
#   ./orchestrator.sh --dry-run --image-prefix hal.dmathome.com/myorg
#   ./orchestrator.sh --image-prefix hal.dmathome.com/myorg
#
# What it does:
#  - ensures host persistent directories exist on each node (local run)
#  - optionally builds and pushes node images (if Dockerfiles present)
#  - removes stale secret refs from openwebui_openwebui
#  - updates openwebui_openwebui with canonical secret + persistent mounts
#  - updates node1/node2 services to use built images (with registry auth)
#
# Safety: when --dry-run is set the script prints commands instead of running them.

DRY_RUN=false
IMAGE_PREFIX="hal.dmathome.com/myorg"
CANONICAL_SECRET="openwebui_hal_router_token_v4_1778210747"
OPENWEBUI_IMAGE="ghcr.io/open-webui/open-webui:latest"
NODE1_DIR="/opt/hal/docker/node1"
NODE2_DIR="/opt/hal/docker/node2"
NODE1_IMAGE_SUFFIX="node1-rag:with-httpx"
NODE2_IMAGE_SUFFIX="node2-rag:with-httpx"
MOUNT_BASE="/opt/hal/data"
OPENWEBUI_SERVICE="openwebui_openwebui"
NODE1_SERVICE="node1_rag-node1"
NODE2_SERVICE="node2_rag-node2"

print() { echo "$@"; }
run() {
  if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN: $*"
  else
    echo "+ $*"
    eval "$@"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --image-prefix) IMAGE_PREFIX="$2"; shift 2 ;;
    --openwebui-image) OPENWEBUI_IMAGE="$2"; shift 2 ;;
    --canonical-secret) CANONICAL_SECRET="$2"; shift 2 ;;
    --help) echo "Usage: $0 [--dry-run] [--image-prefix PREFIX]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# Derived values
NODE1_IMAGE="""/${NODE1_IMAGE_SUFFIX}"
NODE2_IMAGE="""/${NODE2_IMAGE_SUFFIX}"

# 1. Ensure host persistent directories exist (local node)
print "Ensuring host persistent directories exist under ${MOUNT_BASE}..."
run "mkdir -p ${MOUNT_BASE}/openwebui/models ${MOUNT_BASE}/openwebui/cache ${MOUNT_BASE}/openwebui/uploads ${MOUNT_BASE}/openwebui/db ${MOUNT_BASE}/hal_memory"
run "chown -R 1000:1000 ${MOUNT_BASE} || true"
run "chmod -R 750 ${MOUNT_BASE} || true"

# 2. Show current secrets and service secret refs
print "Listing current secrets and openwebui service secret refs..."
run "docker secret ls --format '{{.ID}} {{.Name}} {{.CreatedAt}}' || true"
run "docker service inspect ${OPENWEBUI_SERVICE} --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}' | jq . || true"

# 3. Remove stale secret references (idempotent)
print "Removing known stale secret references from ${OPENWEBUI_SERVICE} (safe)..."
run "docker service update --secret-rm openwebui_hal_router_token_v4 --force ${OPENWEBUI_SERVICE} || true"
run "docker service update --secret-rm openwebui_hal_router_token_v4_1778209596 --force ${OPENWEBUI_SERVICE} || true"
run "docker service update --secret-rm openwebui_hal_router_token_v4_1778210619 --force ${OPENWEBUI_SERVICE} || true"
run "docker service update --secret-rm openwebui_hal_router_token_v4_1778210747 --force ${OPENWEBUI_SERVICE} || true"
run "docker service update --secret-rm openwebui_hal_router_token_v3 --force ${OPENWEBUI_SERVICE} || true"

# 4. Verify no secrets remain in the service spec
print "Verifying service has no secret entries..."
run "docker service inspect ${OPENWEBUI_SERVICE} --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}' | jq . || true"

# 5. Update service with canonical secret and persistent mounts (atomic update)
print "Updating ${OPENWEBUI_SERVICE} to add canonical secret ${CANONICAL_SECRET} and persistent mounts..."
run "docker service update \
  --secret-add source=${CANONICAL_SECRET},target=${CANONICAL_SECRET} \
  --env-add HAL_ROUTER_TOKEN_FILE=/run/secrets/${CANONICAL_SECRET} \
  --mount-add type=bind,src=${MOUNT_BASE}/openwebui/models,dst=/root/.cache/openwebui/models \
  --mount-add type=bind,src=${MOUNT_BASE}/openwebui/cache,dst=/root/.cache/openwebui/cache \
  --mount-add type=bind,src=${MOUNT_BASE}/openwebui/uploads,dst=/app/uploads \
  --mount-add type=bind,src=${MOUNT_BASE}/openwebui/db,dst=/app/db \
  --mount-add type=bind,src=${MOUNT_BASE}/hal_memory,dst=/app/hal_memory \
  --env-add OPENWEBUI_MODELS_DIR=/root/.cache/openwebui/models \
  --env-add OPENWEBUI_UPLOADS_DIR=/app/uploads \
  --env-add HAL_MEMORY_PATH=/app/hal_memory \
  --force \
  ${OPENWEBUI_SERVICE}"

# 6. Optional: build and push node images if Dockerfiles exist
print "Checking for Dockerfiles to build node images..."
if [ -f "${NODE1_DIR}/Dockerfile" ] || [ -f "${NODE1_DIR}/Dockerfile.rag" ]; then
  DOCKERFILE1="${NODE1_DIR}/Dockerfile"
  [ -f "${NODE1_DIR}/Dockerfile.rag" ] && DOCKERFILE1="${NODE1_DIR}/Dockerfile.rag"
  print "Found Dockerfile for node1: ${DOCKERFILE1}"
  run "docker build -t ${NODE1_IMAGE} -f ${DOCKERFILE1} ${NODE1_DIR}"
  run "docker login $(echo "" | cut -d'/' -f1) || true"
  run "docker push ${NODE1_IMAGE} || true"
else
  print "No Dockerfile found for node1; skipping build."
fi

if [ -f "${NODE2_DIR}/Dockerfile" ] || [ -f "${NODE2_DIR}/Dockerfile.rag" ]; then
  DOCKERFILE2="${NODE2_DIR}/Dockerfile"
  [ -f "${NODE2_DIR}/Dockerfile.rag" ] && DOCKERFILE2="${NODE2_DIR}/Dockerfile.rag"
  print "Found Dockerfile for node2: ${DOCKERFILE2}"
  run "docker build -t ${NODE2_IMAGE} -f ${DOCKERFILE2} ${NODE2_DIR}"
  run "docker login $(echo "" | cut -d'/' -f1) || true"
  run "docker push ${NODE2_IMAGE} || true"
else
  print "No Dockerfile found for node2; skipping build."
fi

# 7. Update node services to use new images (if images were pushed)
print "Updating node services to use images ${NODE1_IMAGE} and ${NODE2_IMAGE} (if available)..."
run "docker service update --with-registry-auth --image ${NODE1_IMAGE} --force ${NODE1_SERVICE} || true"
run "docker service update --with-registry-auth --image ${NODE2_IMAGE} --force ${NODE2_SERVICE} || true"

# 8. Final verification commands to run manually or printed in dry-run
print "Final verification commands (run manually if not in dry-run):"
echo "  docker secret ls"
echo "  docker service inspect ${OPENWEBUI_SERVICE} --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}' | jq ."
echo "  docker service ps --no-trunc ${OPENWEBUI_SERVICE}"
echo "  docker service logs ${OPENWEBUI_SERVICE} --tail 200"
echo "  docker service ps --no-trunc ${NODE1_SERVICE} || true"
echo "  docker service ps --no-trunc ${NODE2_SERVICE} || true"

print "Orchestrator finished."
