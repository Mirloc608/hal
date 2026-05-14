#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# rotate_and_build.sh
# Usage:
#   ./rotate_and_build.sh [--image-prefix myrepo] [--push] [--skip-build] [--skip-verify]
# Example:
#   ./rotate_and_build.sh --image-prefix registry.example.com/myorg --push

# -------------------------
# Hard-coded discovered values
# -------------------------
ROUTER_CID="41126171502f"
ROUTER_IP="10.0.1.150"
OPENWEBUI_SERVICE="openwebui_openwebui"
ROUTER_SECRET_PATH="/run/secrets/hal_router_token"

# Engine contexts detected in repo (adjust if your Dockerfile lives elsewhere)
NODE1_CTX="/opt/hal/docker/node1"
NODE2_CTX="/opt/hal/docker/node2"
DEFAULT_IMAGE_PREFIX="myrepo"

# Engine service names
ENGINE_SERVICE_1="node1_rag-node1"
ENGINE_SERVICE_2="node2_rag-node2"

# -------------------------
# CLI args
# -------------------------
IMAGE_PREFIX="${DEFAULT_IMAGE_PREFIX}"
DO_PUSH=false
SKIP_BUILD=false
SKIP_VERIFY=false

while [ $# -gt 0 ]; do
  case "$1" in
    --image-prefix) IMAGE_PREFIX="$2"; shift 2;;
    --push) DO_PUSH=true; shift;;
    --skip-build) SKIP_BUILD=true; shift;;
    --skip-verify) SKIP_VERIFY=true; shift;;
    -h|--help)
      cat <<EOF
Usage: $0 [--image-prefix myrepo] [--push] [--skip-build] [--skip-verify]

--image-prefix  registry/repo prefix for built images (default: ${DEFAULT_IMAGE_PREFIX})
--push          push built images to registry (requires registry access)
--skip-build    skip building images (useful if images already built)
--skip-verify   skip in-container verification steps
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

log(){ printf '\n[+] %s\n' "$1"; }
err(){ printf '\n[!] %s\n' "$1" >&2; }

# -------------------------
# Step 1: ensure router token exists and create new secret v4_timestamp
# -------------------------
log "Checking router token inside container ${ROUTER_CID} at ${ROUTER_SECRET_PATH}..."
if ! docker exec "${ROUTER_CID}" sh -c "test -f ${ROUTER_SECRET_PATH}" >/dev/null 2>&1; then
  err "Router token file ${ROUTER_SECRET_PATH} not found inside container ${ROUTER_CID}."
  exit 2
fi

TS=$(date +%s)
NEW_SECRET="openwebui_hal_router_token_v4_${TS}"
TMPFILE="/tmp/hal_router_token_${TS}"

log "Extracting router token to ${TMPFILE}..."
docker exec "${ROUTER_CID}" sh -c "cat ${ROUTER_SECRET_PATH}" > "${TMPFILE}"

log "Creating swarm secret ${NEW_SECRET}..."
docker secret create "${NEW_SECRET}" "${TMPFILE}" >/dev/null
log "Secret ${NEW_SECRET} created."

# -------------------------
# Step 2: remove old v4/v2 references from service and remove old v4 secret objects
# -------------------------
log "Removing any existing v4/v2 secret references from service ${OPENWEBUI_SERVICE} (safe)..."
docker service update --secret-rm openwebui_hal_router_token_v4 --force "${OPENWEBUI_SERVICE}" >/dev/null 2>&1 || true
docker service update --secret-rm openwebui_hal_router_token_v4_1778207849 --force "${OPENWEBUI_SERVICE}" >/dev/null 2>&1 || true
docker service update --secret-rm openwebui_hal_router_token_v4_1778208642 --force "${OPENWEBUI_SERVICE}" >/dev/null 2>&1 || true
docker service update --secret-rm openwebui_hal_router_token_v2 --force "${OPENWEBUI_SERVICE}" >/dev/null 2>&1 || true

log "Listing existing openwebui_hal_router_token_v4* secrets (before cleanup):"
docker secret ls --format '{{.ID}} {{.Name}} {{.CreatedAt}}' | grep openwebui_hal_router_token_v4 || true

# Attempt to remove older v4 secrets that are not the one we just created.
for s in $(docker secret ls --format '{{.Name}}' | grep '^openwebui_hal_router_token_v4' || true); do
  if [ "$s" != "${NEW_SECRET}" ]; then
    log "Removing old secret object ${s} (if not referenced)..."
    docker secret rm "${s}" >/dev/null 2>&1 || log "Could not remove ${s} (may still be referenced)."
  fi
done

log "Current secrets after cleanup:"
docker secret ls --format '{{.ID}} {{.Name}} {{.CreatedAt}}' | grep openwebui_hal_router_token_v4 || true

# -------------------------
# Step 3: attach canonical secret to OpenWebUI service and set env
# -------------------------
HAL_ENV_PATH="/run/secrets/${NEW_SECRET}"
log "Adding ${NEW_SECRET} to ${OPENWEBUI_SERVICE} and setting HAL_ROUTER_TOKEN_FILE=${HAL_ENV_PATH}..."
docker service update \
  --secret-add "source=${NEW_SECRET},target=${NEW_SECRET}" \
  --env-add "HAL_ROUTER_TOKEN_FILE=${HAL_ENV_PATH}" \
  --force \
  "${OPENWEBUI_SERVICE}"

log "Waiting 8s for service tasks to converge..."
sleep 8
docker service ps --no-trunc "${OPENWEBUI_SERVICE}" || true

# -------------------------
# Step 4: verify secret mounted inside running task (if local)
# -------------------------
if [ "${SKIP_VERIFY}" = false ]; then
  log "Attempting to verify secret is mounted inside a running OpenWebUI task (if task is on this host)."
  RUNNING_TASK_INFO=$(docker service ps --filter "desired-state=running" --no-trunc "${OPENWEBUI_SERVICE}" --format '{{.ID}} {{.Node}} {{.CurrentState}}' | head -n1 || true)
  if [ -n "${RUNNING_TASK_INFO}" ]; then
    TASK_CID=$(docker ps --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "${OPENWEBUI_SERVICE}|hal-openwebui" | awk '{print $1}' | head -n1 || true)
    if [ -n "${TASK_CID}" ]; then
      log "Found local container ${TASK_CID}; listing /run/secrets inside it..."
      docker exec "${TASK_CID}" sh -c "ls -l /run/secrets || true; cat ${HAL_ENV_PATH} || echo 'secret not present in this container'"
    else
      log "No local container for ${OPENWEBUI_SERVICE} found on this node; run verification on the node where the task is scheduled."
    fi
  else
    log "No running task found for ${OPENWEBUI_SERVICE} to verify."
  fi
else
  log "Skipping in-container verification (--skip-verify)."
fi

# -------------------------
# Step 5: ensure httpx in engine requirements (append if missing)
# -------------------------
REQ_LINE="httpx>=0.24.0"
for ctx in "${NODE1_CTX}" "${NODE2_CTX}"; do
  REQ_FILE="${ctx}/requirements.txt"
  if [ -f "${REQ_FILE}" ]; then
    if ! grep -qE '^httpx' "${REQ_FILE}"; then
      log "Appending ${REQ_LINE} to ${REQ_FILE}..."
      printf "\n%s\n" "${REQ_LINE}" >> "${REQ_FILE}"
    else
      log "httpx already present in ${REQ_FILE}; skipping."
    fi
  else
    log "No requirements.txt at ${REQ_FILE}; will rely on Dockerfile pip install if needed."
  fi
done

# -------------------------
# Step 6: build and optionally push engine images, then update services
# -------------------------
IMAGE1="${IMAGE_PREFIX}/node1-rag:with-httpx"
IMAGE2="${IMAGE_PREFIX}/node2-rag:with-httpx"

if [ "${SKIP_BUILD}" = false ]; then
  if [ -d "${NODE1_CTX}" ]; then
    log "Building ${IMAGE1} from ${NODE1_CTX}..."
    docker build -t "${IMAGE1}" "${NODE1_CTX}"
  else
    log "Engine context ${NODE1_CTX} not found; skipping build for node1."
  fi

  if [ -d "${NODE2_CTX}" ]; then
    log "Building ${IMAGE2} from ${NODE2_CTX}..."
    docker build -t "${IMAGE2}" "${NODE2_CTX}"
  else
    log "Engine context ${NODE2_CTX} not found; skipping build for node2."
  fi
else
  log "Skipping build step (--skip-build)."
fi

if [ "${DO_PUSH}" = true ]; then
  log "Pushing images to registry..."
  if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE1}$"; then
    docker push "${IMAGE1}"
  else
    log "Image ${IMAGE1} not found locally; skipping push."
  fi
  if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE2}$"; then
    docker push "${IMAGE2}"
  else
    log "Image ${IMAGE2} not found locally; skipping push."
  fi
else
  log "Not pushing images (--push not set)."
fi

# Update engine services (use --with-registry-auth if pushing)
if docker service ls --format '{{.Name}}' | grep -q "^${ENGINE_SERVICE_1}$"; then
  log "Updating service ${ENGINE_SERVICE_1} to ${IMAGE1}..."
  if [ "${DO_PUSH}" = true ]; then
    docker service update --with-registry-auth --image "${IMAGE1}" --force "${ENGINE_SERVICE_1}" || log "Service update failed for ${ENGINE_SERVICE_1}"
  else
    docker service update --image "${IMAGE1}" --force "${ENGINE_SERVICE_1}" || log "Service update failed for ${ENGINE_SERVICE_1}"
  fi
else
  log "Service ${ENGINE_SERVICE_1} not found; skipping update."
fi

if docker service ls --format '{{.Name}}' | grep -q "^${ENGINE_SERVICE_2}$"; then
  log "Updating service ${ENGINE_SERVICE_2} to ${IMAGE2}..."
  if [ "${DO_PUSH}" = true ]; then
    docker service update --with-registry-auth --image "${IMAGE2}" --force "${ENGINE_SERVICE_2}" || log "Service update failed for ${ENGINE_SERVICE_2}"
  else
    docker service update --image "${IMAGE2}" --force "${ENGINE_SERVICE_2}" || log "Service update failed for ${ENGINE_SERVICE_2}"
  fi
else
  log "Service ${ENGINE_SERVICE_2} not found; skipping update."
fi

log "Waiting a few seconds for engine service updates to start..."
sleep 6
docker service ps --no-trunc "${ENGINE_SERVICE_1}" || true
docker service ps --no-trunc "${ENGINE_SERVICE_2}" || true

# -------------------------
# Final checks and instructions
# -------------------------
log "Rotation and updates complete. Run these checks now (copy/paste):"

cat <<EOF

1) Confirm canonical secret exists:
   docker secret ls | grep ${NEW_SECRET}

2) Confirm OpenWebUI service references the secret:
   docker service inspect ${OPENWEBUI_SERVICE} --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}' | jq .

3) Verify secret inside running OpenWebUI task (on node where task runs):
   # find node and container, then:
   docker exec -it <task_container_id> sh -c 'ls -l /run/secrets || true; cat /run/secrets/${NEW_SECRET} || echo "secret not present"'

4) Test router endpoints:
   export TOKEN=\$(docker exec ${ROUTER_CID} sh -c 'cat ${ROUTER_SECRET_PATH}')
   curl -sS -H "Authorization: Bearer \$TOKEN" "http://${ROUTER_IP}:9000/openai/models" | jq .
   curl -sS -H "Authorization: Bearer \$TOKEN" "http://${ROUTER_IP}:9000/routing/why?model=deepseek-coder:6.7b" | jq .

5) Watch logs:
   docker service logs ${ENGINE_SERVICE_1} --tail 200 -f
   docker service logs ${ENGINE_SERVICE_2} --tail 200 -f
   docker service logs router_hal-router --tail 200 -f

EOF

log "Script finished."
