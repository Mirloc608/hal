#!/usr/bin/env bash
set -euo pipefail

# --- Configuration (values discovered on your host) ---
SERVICE_NAME="openwebui_openwebui"
OPENWEBUI_CID="e63a6ec663b2"            # hal-openwebui container on this host
ROUTER_CID="41126171502f"               # router_hal-router container id
ROUTER_IP="10.0.1.150"                  # router IP on hal_cluster_net
SECRET_V2="openwebui_hal_router_token_v2"
SECRET_V3="openwebui_hal_router_token_v3"
SECRET_PATH_V2="/run/secrets/${SECRET_V2}"
SECRET_PATH_V3="/run/secrets/${SECRET_V3}"

# --- Helper functions ---
log() { printf '\n[+] %s\n' "$1"; }

# 1) Show current secret mapping and env in the service spec
log "Inspecting service spec for ${SERVICE_NAME} (secrets and env)..."
docker service inspect "${SERVICE_NAME}" --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}' | jq . || true
docker service inspect "${SERVICE_NAME}" --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | jq . || true

# 2) Attempt to remove any existing reference to SECRET_V2 (safe: ignore failures)
log "Removing secret reference ${SECRET_V2} from service (if present)..."
if docker service inspect "${SERVICE_NAME}" --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}' | jq -e 'map(.SecretName) | index("'"${SECRET_V2}"'")' >/dev/null 2>&1; then
  docker service update --secret-rm "${SECRET_V2}" --force "${SERVICE_NAME}" || {
    log "Warning: removal of ${SECRET_V2} rolled back or failed; continuing."
  }
else
  log "Secret ${SECRET_V2} not referenced in service spec; skipping removal."
fi

# 3) Re-add SECRET_V2 as target once and set HAL_ROUTER_TOKEN_FILE env
log "Adding secret ${SECRET_V2} back to service and setting HAL_ROUTER_TOKEN_FILE env..."
docker service update \
  --secret-add "source=${SECRET_V2},target=${SECRET_V2}" \
  --env-add "HAL_ROUTER_TOKEN_FILE=${SECRET_PATH_V2}" \
  --force \
  "${SERVICE_NAME}" || {
    log "Error: failed to add ${SECRET_V2} to service. Attempting to continue to verification steps."
  }

# 4) Wait a short while for the service task to converge and then show tasks
log "Waiting 5 seconds for service tasks to converge..."
sleep 5
log "Service tasks for ${SERVICE_NAME}:"
docker service ps --no-trunc "${SERVICE_NAME}" || true

# 5) Find a running container for the service (fallback to provided OPENWEBUI_CID)
log "Locating a running container for ${SERVICE_NAME}..."
TASK_CID=$(docker ps --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "${SERVICE_NAME}|hal-openwebui" | awk '{print $1}' | head -n1 || true)
if [ -z "${TASK_CID}" ]; then
  log "No service task container found via docker ps; falling back to provided OPENWEBUI_CID=${OPENWEBUI_CID}"
  TASK_CID="${OPENWEBUI_CID}"
fi
log "Using container id: ${TASK_CID}"

# 6) Inspect /run/secrets inside the OpenWebUI container and print the token file contents if present
log "Listing /run/secrets inside container ${TASK_CID} and attempting to cat ${SECRET_PATH_V2}..."
docker exec -it "${TASK_CID}" sh -c "ls -l /run/secrets || true; cat ${SECRET_PATH_V2} || echo 'SECRET_V2 not present in container ${TASK_CID}'"

# 7) Inspect router container secrets and read token (router may hold the canonical secret)
log "Listing /run/secrets inside router container ${ROUTER_CID} and attempting to cat ${SECRET_PATH_V2} and ${SECRET_PATH_V3}..."
docker exec -it "${ROUTER_CID}" sh -c "ls -l /run/secrets || true; cat ${SECRET_PATH_V2} || true; cat ${SECRET_PATH_V3} || true"

# 8) Export TOKEN from router container secret (prefer v3 then v2)
log "Reading token from router container into host env var TOKEN (prefer ${SECRET_V3} then ${SECRET_V2})..."
TOKEN=""
if docker exec "${ROUTER_CID}" sh -c "test -f ${SECRET_PATH_V3}" >/dev/null 2>&1; then
  TOKEN=$(docker exec "${ROUTER_CID}" sh -c "cat ${SECRET_PATH_V3}")
  log "Using token from ${SECRET_PATH_V3}"
elif docker exec "${ROUTER_CID}" sh -c "test -f ${SECRET_PATH_V2}" >/dev/null 2>&1; then
  TOKEN=$(docker exec "${ROUTER_CID}" sh -c "cat ${SECRET_PATH_V2}")
  log "Using token from ${SECRET_PATH_V2}"
else
  log "No token file found in router container at ${SECRET_PATH_V3} or ${SECRET_PATH_V2}. Exiting."
  exit 1
fi
export TOKEN

# 9) Test router endpoints from the host using the router IP discovered on this host
log "Testing router endpoints at http://${ROUTER_IP}:9000 using the token read from router container..."
log "GET /openai/models"
curl -sS -H "Authorization: Bearer ${TOKEN}" "http://${ROUTER_IP}:9000/openai/models" | jq . || true

log "GET /routing/why?model=deepseek-coder:6.7b"
curl -sS -H "Authorization: Bearer ${TOKEN}" "http://${ROUTER_IP}:9000/routing/why?model=deepseek-coder:6.7b" | jq . || true

log "POST /v1/chat/completions (simple test)"
curl -sS -i -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
  "http://${ROUTER_IP}:9000/v1/chat/completions" \
  -d '{"model":"deepseek-coder:6.7b","messages":[{"role":"user","content":"Hello"}]}' || true

# 10) If you want to switch to SECRET_V3, update the service to use it (uncomment to enable)
: <<'SWITCH_SECRET_V3'
log "Switching service to use ${SECRET_V3} and updating HAL_ROUTER_TOKEN_FILE..."
docker service update \
  --secret-rm "${SECRET_V2}" \
  --secret-add "source=${SECRET_V3},target=${SECRET_V3}" \
  --env-add "HAL_ROUTER_TOKEN_FILE=${SECRET_PATH_V3}" \
  --force \
  "${SERVICE_NAME}"
log "Waiting 5 seconds for service to converge..."
sleep 5
docker service ps --no-trunc "${SERVICE_NAME}"
SWITCH_SECRET_V3

log "Script completed."
