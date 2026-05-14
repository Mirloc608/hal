#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# --- Discovered values from your host (hard-coded) ---
ROUTER_CID="41126171502f"
ROUTER_IP="10.0.1.150"
OPENWEBUI_CID="e63a6ec663b2"
SERVICE_NAME="openwebui_openwebui"
SECRET_NAME_V3="openwebui_hal_router_token_v3"
SECRET_NAME_V2="openwebui_hal_router_token_v2"
ROUTER_SECRET_PATH="/run/secrets/hal_router_token"
HAL_ENV_PATH_V3="/run/secrets/${SECRET_NAME_V3}"
HAL_ENV_PATH_V2="/run/secrets/${SECRET_NAME_V2}"
ENGINE_SERVICE_1="node1_rag-node1"
ENGINE_SERVICE_2="node2_rag-node2"

log() { printf '\n[+] %s\n' "$1"; }

# --- 1) Extract router token and recreate secret openwebui_hal_router_token_v3 ---
log "Reading token from router container ${ROUTER_CID} at ${ROUTER_SECRET_PATH}..."
if ! docker exec "${ROUTER_CID}" sh -c "test -f ${ROUTER_SECRET_PATH}" >/dev/null 2>&1; then
  log "ERROR: token file ${ROUTER_SECRET_PATH} not found inside router container ${ROUTER_CID}."
  exit 1
fi

log "Removing existing Docker secret ${SECRET_NAME_V3} (if present)..."
docker secret rm "${SECRET_NAME_V3}" >/dev/null 2>&1 || true

log "Creating Docker secret ${SECRET_NAME_V3} from router container token..."
docker exec "${ROUTER_CID}" sh -c "cat ${ROUTER_SECRET_PATH}" | docker secret create "${SECRET_NAME_V3}" - >/dev/null

log "Confirming secret ${SECRET_NAME_V3} exists..."
docker secret ls --format '{{.Name}}' | grep -x "${SECRET_NAME_V3}" >/dev/null

# --- 2) Update openwebui service to use the new secret and HAL_ROUTER_TOKEN_FILE env ---
log "Updating service ${SERVICE_NAME} to use ${SECRET_NAME_V3} and HAL_ROUTER_TOKEN_FILE=${HAL_ENV_PATH_V3}..."
# Remove v2 if present, add v3 and set env
docker service update \
  --secret-rm "${SECRET_NAME_V2}" >/dev/null 2>&1 || true

docker service update \
  --secret-add "source=${SECRET_NAME_V3},target=${SECRET_NAME_V3}" \
  --env-add "HAL_ROUTER_TOKEN_FILE=${HAL_ENV_PATH_V3}" \
  --force \
  "${SERVICE_NAME}"

log "Waiting for service ${SERVICE_NAME} tasks to converge (10s)..."
sleep 10
docker service ps --no-trunc "${SERVICE_NAME}" || true

# --- 3) Verify the secret is mounted inside the running OpenWebUI task (if a container is available) ---
log "Checking /run/secrets inside OpenWebUI container ${OPENWEBUI_CID} (if present on this host)..."
if docker ps -q --no-trunc | grep -q "^${OPENWEBUI_CID}$"; then
  docker exec -it "${OPENWEBUI_CID}" sh -c "ls -l /run/secrets || true; cat ${HAL_ENV_PATH_V3} || echo 'secret not present in container ${OPENWEBUI_CID}'"
else
  log "Container ${OPENWEBUI_CID} not present on this host; check the running task container id from 'docker service ps ${SERVICE_NAME}'."
fi

# --- 4) Export TOKEN from router container for host curl tests ---
log "Exporting TOKEN from router container ${ROUTER_CID} into host env var TOKEN..."
export TOKEN=$(docker exec "${ROUTER_CID}" sh -c "cat ${ROUTER_SECRET_PATH}")
if [ -z "${TOKEN}" ]; then
  log "ERROR: token read from router is empty."
  exit 1
fi

# --- 5) Test router endpoints (models and routing) ---
log "Testing router: GET /openai/models"
curl -sS -H "Authorization: Bearer ${TOKEN}" "http://${ROUTER_IP}:9000/openai/models" | jq . || true

log "Testing router: GET /routing/why?model=deepseek-coder:6.7b"
curl -sS -H "Authorization: Bearer ${TOKEN}" "http://${ROUTER_IP}:9000/routing/why?model=deepseek-coder:6.7b" | jq . || true

# --- 6) Temporary engine fix: attempt to pip install httpx inside running engine containers (non-persistent) ---
log "Attempting quick debug install of httpx inside running engine containers (ephemeral)."
for svc in "${ENGINE_SERVICE_1}" "${ENGINE_SERVICE_2}"; do
  # pick a running container for the service
  CID=$(docker ps --filter "name=${svc}" --format '{{.ID}}' | head -n1 || true)
  if [ -n "${CID}" ]; then
    log "Found container ${CID} for service ${svc}; installing httpx (temporary)..."
    docker exec -it "${CID}" sh -c "python -m pip install --no-cache-dir httpx" || log "pip install failed in ${CID}; service will still need a rebuilt image."
    log "Tail last 50 lines of logs for ${svc} (non-blocking):"
    docker service logs "${svc}" --tail 50 || true
  else
    log "No running container found for ${svc} on this host; service may be scheduled on another node."
  fi
done

# --- 7) Advise permanent engine fix (non-automated) and optionally trigger service update if new image is available ---
log "Permanent fix: rebuild engine images to include httpx and update services. Example commands (manual step):"
cat <<'EOF'
# Example (manual):
# 1) Add `httpx` to engine requirements.txt or Dockerfile.
# 2) Build and push new image:
docker build -t myrepo/node1-rag:with-httpx /path/to/engine/context
docker push myrepo/node1-rag:with-httpx
# 3) Update service:
docker service update --image myrepo/node1-rag:with-httpx --force node1_rag-node1
docker service update --image myrepo/node2-rag:with-httpx --force node2_rag-node2
EOF

# --- 8) Final routing check and quick chat test (if engines become healthy) ---
log "Final routing check (repeat):"
curl -sS -H "Authorization: Bearer ${TOKEN}" "http://${ROUTER_IP}:9000/routing/why?model=deepseek-coder:6.7b" | jq . || true

log "If routing shows healthy engines, run a quick chat test:"
cat <<EOF
curl -i -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
  "http://${ROUTER_IP}:9000/v1/chat/completions" \
  -d '{"model":"deepseek-coder:6.7b","messages":[{"role":"user","content":"Hello"}]}'
EOF

log "Script finished. If engines still crash with ModuleNotFoundError for httpx, rebuild engine images to include httpx and redeploy the services."
