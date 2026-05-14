#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# File: /opt/hal/scripts/rotate_secret_and_update.sh
# Usage:
#   ./rotate_secret_and_update.sh [--engine-path /path/to/engine] [--image myrepo/node1-rag:tag] [--services node1_rag-node1,node2_rag-node2] [--push] [--skip-verify]
#
# Examples:
#   ./rotate_secret_and_update.sh
#   ./rotate_secret_and_update.sh --engine-path /home/hal/engine --image myrepo/node1-rag:with-httpx --services node1_rag-node1,node2_rag-node2 --push

# -------------------------
# Configuration (discovered)
# -------------------------
ROUTER_CID="41126171502f"            # discovered router container id
ROUTER_IP="10.0.1.150"               # discovered router cluster IP
OPENWEBUI_SERVICE="openwebui_openwebui"
ROUTER_SECRET_PATH="/run/secrets/hal_router_token"
NEW_SECRET_NAME="openwebui_hal_router_token_v4"
HAL_ENV_PATH="/run/secrets/${NEW_SECRET_NAME}"

# -------------------------
# Defaults for optional build/push
# -------------------------
ENGINE_CONTEXT=""
IMAGE_NAME=""
ENGINE_SERVICES="node1_rag-node1,node2_rag-node2"
DO_PUSH=false
SKIP_VERIFY=false

# -------------------------
# Helpers
# -------------------------
log() { printf '\n[+] %s\n' "$1"; }
err() { printf '\n[!] %s\n' "$1" >&2; }

usage() {
  cat <<EOF
Usage: $0 [--engine-path PATH] [--image IMAGE] [--services svc1,svc2] [--push] [--skip-verify]

Options:
  --engine-path PATH   Path to engine Docker build context (optional).
  --image IMAGE        Image name:tag to build and push (optional).
  --services LIST      Comma-separated engine service names to update (default: ${ENGINE_SERVICES}).
  --push               Push built image to registry (requires IMAGE).
  --skip-verify        Skip verification steps that exec into containers (useful if running from a different node).
  -h, --help           Show this help and exit.

Examples:
  $0
  $0 --engine-path /home/hal/engine --image myrepo/node1-rag:with-httpx --push --services node1_rag-node1,node2_rag-node2
EOF
  exit 1
}

# -------------------------
# Parse args
# -------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --engine-path) ENGINE_CONTEXT="$2"; shift 2;;
    --image) IMAGE_NAME="$2"; shift 2;;
    --services) ENGINE_SERVICES="$2"; shift 2;;
    --push) DO_PUSH=true; shift;;
    --skip-verify) SKIP_VERIFY=true; shift;;
    -h|--help) usage;;
    *) err "Unknown arg: $1"; usage;;
  esac
done

# -------------------------
# Preconditions
# -------------------------
if ! command -v docker >/dev/null 2>&1; then
  err "docker CLI not found. Run this on a host with Docker and Swarm manager access."
  exit 2
fi

log "Starting secret rotation and optional engine image update."
log "Router container: ${ROUTER_CID}, Router IP: ${ROUTER_IP}"
log "New secret name: ${NEW_SECRET_NAME}"
if [ -n "${IMAGE_NAME}" ]; then
  log "Engine image requested: ${IMAGE_NAME}"
  if [ -z "${ENGINE_CONTEXT}" ]; then
    err "Engine image specified but --engine-path not provided."
    exit 3
  fi
fi

# -------------------------
# Step A: Create new secret v4 from router token (safe rotation)
# -------------------------
log "Verifying router token file exists inside router container ${ROUTER_CID}..."
if ! docker exec "${ROUTER_CID}" sh -c "test -f ${ROUTER_SECRET_PATH}" >/dev/null 2>&1; then
  err "Router token file ${ROUTER_SECRET_PATH} not found inside container ${ROUTER_CID}."
  exit 4
fi

log "Creating temporary file /tmp/hal_router_token from router container..."
docker exec "${ROUTER_CID}" sh -c "cat ${ROUTER_SECRET_PATH}" > /tmp/hal_router_token

# If a secret with the new name already exists, create a unique name by appending timestamp
if docker secret ls --format '{{.Name}}' | grep -xq "${NEW_SECRET_NAME}"; then
  TIMESTAMP=$(date +%s)
  NEW_SECRET_NAME="${NEW_SECRET_NAME}_${TIMESTAMP}"
  HAL_ENV_PATH="/run/secrets/${NEW_SECRET_NAME}"
  log "Secret name already existed; using new name: ${NEW_SECRET_NAME}"
fi

log "Creating swarm secret ${NEW_SECRET_NAME} from /tmp/hal_router_token..."
docker secret create "${NEW_SECRET_NAME}" /tmp/hal_router_token >/dev/null
log "Secret ${NEW_SECRET_NAME} created."

# -------------------------
# Step B: Update OpenWebUI service to mount new secret and force redeploy
# -------------------------
log "Removing any old secret references from service ${OPENWEBUI_SERVICE} (safe)..."
docker service update --secret-rm openwebui_hal_router_token_v3 --force "${OPENWEBUI_SERVICE}" >/dev/null 2>&1 || true
docker service update --secret-rm openwebui_hal_router_token_v2 --force "${OPENWEBUI_SERVICE}" >/dev/null 2>&1 || true

log "Adding ${NEW_SECRET_NAME} to ${OPENWEBUI_SERVICE} and setting HAL_ROUTER_TOKEN_FILE=${HAL_ENV_PATH}..."
docker service update \
  --secret-add "source=${NEW_SECRET_NAME},target=${NEW_SECRET_NAME}" \
  --env-add "HAL_ROUTER_TOKEN_FILE=${HAL_ENV_PATH}" \
  --force \
  "${OPENWEBUI_SERVICE}"

log "Waiting for OpenWebUI service tasks to converge (sleep 8s)..."
sleep 8
docker service ps --no-trunc "${OPENWEBUI_SERVICE}" || true

# Optional verification: check secret inside running task container (only if not skipped)
if [ "${SKIP_VERIFY}" = false ]; then
  log "Attempting to verify secret is mounted inside a running OpenWebUI task (if task is on this host)."
  RUNNING_TASK=$(docker service ps --filter "desired-state=running" --no-trunc "${OPENWEBUI_SERVICE}" --format '{{.ID}} {{.Node}} {{.CurrentState}}' | head -n1 || true)
  if [ -n "${RUNNING_TASK}" ]; then
    # Try to find the container id for the running task on this host
    TASK_CID=$(docker ps --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "${OPENWEBUI_SERVICE}|hal-openwebui" | awk '{print $1}' | head -n1 || true)
    if [ -n "${TASK_CID}" ]; then
      log "Found local container ${TASK_CID}; listing /run/secrets inside it..."
  # robust verification: avoid nested double quotes; use single-quote wrapper and inject variable safely
  if [ -n "${TASK_CID}" ]; then
    docker exec -it "${TASK_CID}" sh -c 'ls -l /run/secrets || true; cat "" || echo "secret not present in this container"'
  else
    echo "No local container for ${OPENWEBUI_SERVICE} found on this node; run verification on the node where the task is scheduled."
  fi
    else
      log "No local container for ${OPENWEBUI_SERVICE} found on this node; run the verification on the node where the task is scheduled."
    fi
  else
    log "No running task found for ${OPENWEBUI_SERVICE} to verify."
  fi
else
  log "Skipping verification inside containers (--skip-verify)."
fi

# -------------------------
# Step C: Optional build/push engine image and update engine services
# -------------------------
if [ -n "${IMAGE_NAME}" ]; then
  log "Building engine image ${IMAGE_NAME} from context ${ENGINE_CONTEXT}..."
  if [ ! -d "${ENGINE_CONTEXT}" ]; then
    err "Engine context directory ${ENGINE_CONTEXT} not found."
    exit 5
  fi

  # Build
  docker build -t "${IMAGE_NAME}" "${ENGINE_CONTEXT"

  if [ "${DO_PUSH}" = true ]; then
    log "Pushing image ${IMAGE_NAME} to registry..."
    docker push "${IMAGE_NAME}"
  else
    log "Skipping push (--push not set). If worker nodes cannot pull the image, use --push and ensure registry access."
  fi

  # Update services (comma-separated list)
  IFS=',' read -r -a SVC_ARR <<< "${ENGINE_SERVICES}"
  for svc in "${SVC_ARR[@]}"; do
    svc_trimmed=$(echo "${svc}" | xargs)
    if [ -z "${svc_trimmed}" ]; then
      continue
    fi
    log "Updating service ${svc_trimmed} to image ${IMAGE_NAME} with registry auth..."
    if [ "${DO_PUSH}" = true ]; then
      docker service update --with-registry-auth --image "${IMAGE_NAME}" --force "${svc_trimmed}" || {
        err "Service update for ${svc_trimmed} failed. Check image availability and node registry auth."
      }
    else
      docker service update --image "${IMAGE_NAME}" --force "${svc_trimmed}" || {
        err "Service update for ${svc_trimmed} failed. Consider using --push and --with-registry-auth."
      }
    fi
  done

  log "Waiting a few seconds for engine service updates to start..."
  sleep 6
  for svc in "${SVC_ARR[@]}"; do
    svc_trimmed=$(echo "${svc}" | xargs)
    docker service ps --no-trunc "${svc_trimmed}" || true
  done
else
  log "No engine image requested; skipping build/push and engine service updates."
fi

# -------------------------
# Final checks and instructions
# -------------------------
log "Rotation and updates complete. Quick checks you can run now:"
cat <<EOF

1) Confirm secret exists:
   docker secret ls | grep ${NEW_SECRET_NAME}

2) Confirm OpenWebUI service references the secret:
   docker service inspect ${OPENWEBUI_SERVICE} --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}' | jq .

3) If you updated engine images, watch logs:
   docker service logs node1_rag-node1 --tail 200 -f
   docker service logs node2_rag-node2 --tail 200 -f

4) Test router endpoints (use token from router container):
   export TOKEN=\$(docker exec ${ROUTER_CID} sh -c 'cat ${ROUTER_SECRET_PATH}')
   curl -sS -H "Authorization: Bearer \$TOKEN" "http://${ROUTER_IP}:9000/openai/models" | jq .
   curl -sS -H "Authorization: Bearer \$TOKEN" "http://${ROUTER_IP}:9000/routing/why?model=deepseek-coder:6.7b" | jq .

EOF

log "Script finished."
