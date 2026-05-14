#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# migrate_to_persistent_storage.sh
# Usage:
#   sudo /opt/hal/scripts/migrate_to_persistent_storage.sh [--dry-run] [--use-volumes] [--deploy-postgres] [--keep-secret existing|create]
# Examples:
#   sudo ./migrate_to_persistent_storage.sh --dry-run
#   sudo ./migrate_to_persistent_storage.sh --use-volumes --deploy-postgres --keep-secret create

# -------------------------
# Configuration (adjust if needed)
# -------------------------
ROUTER_CID="41126171502f"
ROUTER_IP="10.0.1.150"
OPENWEBUI_SERVICE="openwebui_openwebui"

# Host persistent paths (bind mounts)
HOST_BASE="/opt/hal/data"
OPENWEBUI_MODELS="${HOST_BASE}/openwebui/models"
OPENWEBUI_CACHE="${HOST_BASE}/openwebui/cache"
OPENWEBUI_UPLOADS="${HOST_BASE}/openwebui/uploads"
OPENWEBUI_DB="${HOST_BASE}/openwebui/db"
HAL_MEMORY="${HOST_BASE}/hal_memory"

# Docker named volumes (alternative)
VOL_MODELS="hal_openwebui_models"
VOL_CACHE="hal_openwebui_cache"
VOL_UPLOADS="hal_openwebui_uploads"
VOL_DB="hal_openwebui_db"
VOL_HAL_MEMORY="hal_hal_memory"

# Postgres settings (optional)
POSTGRES_SERVICE="hal_postgres"
POSTGRES_VOLUME="pgdata_hal"
POSTGRES_USER="hal"
POSTGRES_DB="hal_memory"
POSTGRES_PASSWORD="changeme"   # change this for production

# Defaults
DRY_RUN=false
USE_VOLUMES=false
DEPLOY_POSTGRES=false
KEEP_SECRET="existing"   # options: existing | create

# -------------------------
# Helpers
# -------------------------
log(){ printf '\n[+] %s\n' "$1"; }
run(){ if [ "$DRY_RUN" = true ]; then printf 'DRY RUN: %s\n' "$*"; else eval "$*"; fi }
err(){ printf '\n[!] %s\n' "$1" >&2; }

# -------------------------
# Parse args
# -------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift;;
    --use-volumes) USE_VOLUMES=true; shift;;
    --deploy-postgres) DEPLOY_POSTGRES=true; shift;;
    --keep-secret) KEEP_SECRET="$2"; shift 2;;
    -h|--help)
      cat <<EOF
Usage: $0 [--dry-run] [--use-volumes] [--deploy-postgres] [--keep-secret existing|create]

--dry-run         Show actions without executing them.
--use-volumes     Use Docker named volumes instead of host bind mounts.
--deploy-postgres Deploy a Postgres service for HAL memory (uses POSTGRES_PASSWORD variable).
--keep-secret     existing (leave secrets alone) or create (create new secret from router token).
EOF
      exit 0
      ;;
    *) err "Unknown arg: $1"; exit 1;;
  esac
done

# -------------------------
# Safety checks
# -------------------------
if [ "$(id -u)" -ne 0 ]; then
  err "This script should be run as root or with sudo because it creates host directories and updates services."
  exit 3
fi

log "DRY_RUN=${DRY_RUN}, USE_VOLUMES=${USE_VOLUMES}, DEPLOY_POSTGRES=${DEPLOY_POSTGRES}, KEEP_SECRET=${KEEP_SECRET}"
log "Router container: ${ROUTER_CID}, OpenWebUI service: ${OPENWEBUI_SERVICE}"

# -------------------------
# Step 1: create host directories or volumes
# -------------------------
if [ "${USE_VOLUMES}" = true ]; then
  log "Creating Docker named volumes (if not present)..."
  run "docker volume create --name ${VOL_MODELS} || true"
  run "docker volume create --name ${VOL_CACHE} || true"
  run "docker volume create --name ${VOL_UPLOADS} || true"
  run "docker volume create --name ${VOL_DB} || true"
  run "docker volume create --name ${VOL_HAL_MEMORY} || true"
else
  log "Creating host directories under ${HOST_BASE} (if not present)..."
  run "mkdir -p ${OPENWEBUI_MODELS} ${OPENWEBUI_CACHE} ${OPENWEBUI_UPLOADS} ${OPENWEBUI_DB} ${HAL_MEMORY}"
  # set permissive ownership so containers can write; adjust UID/GID as needed
  run "chown -R 1000:1000 ${HOST_BASE} || true"
  run "chmod -R 750 ${HOST_BASE} || true"
fi

# -------------------------
# Step 2: optionally create a new secret from router token (safe)
# -------------------------
if [ "${KEEP_SECRET}" = "create" ]; then
  log "Creating a new timestamped secret from router token inside container ${ROUTER_CID}..."
  TS=$(date +%s)
  NEW_SECRET="openwebui_hal_router_token_v4_${TS}"
  TMP="/tmp/hal_router_token_${TS}"
  run "docker exec ${ROUTER_CID} sh -c 'cat /run/secrets/hal_router_token' > ${TMP} || true"
  run "docker secret create ${NEW_SECRET} ${TMP} || true"
  log "Created secret ${NEW_SECRET} (or reported already exists)."
else
  log "Keeping existing secrets unchanged."
fi

# -------------------------
# Step 3: copy existing data from a running container (best-effort)
# -------------------------
# Attempt to find a local OpenWebUI container to copy from (best-effort)
LOCAL_CID=$(docker ps --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E 'hal-openwebui|openwebui' | awk '{print $1}' | head -n1 || true)
if [ -n "${LOCAL_CID}" ]; then
  log "Found local container ${LOCAL_CID}; attempting to copy common OpenWebUI paths into host storage (best-effort)."
  # models
  if [ "${USE_VOLUMES}" = false ]; then
    run "docker exec ${LOCAL_CID} sh -c 'test -d /root/.cache/openwebui/models' && docker exec ${LOCAL_CID} tar -C /root/.cache/openwebui -cf - models | tar -C ${OPENWEBUI_MODELS} -xvf - || true"
    run "docker exec ${LOCAL_CID} sh -c 'test -d /root/.cache/openwebui/cache' && docker exec ${LOCAL_CID} tar -C /root/.cache/openwebui -cf - cache | tar -C ${OPENWEBUI_CACHE} -xvf - || true"
    run "docker exec ${LOCAL_CID} sh -c 'test -d /app/uploads' && docker exec ${LOCAL_CID} tar -C /app -cf - uploads | tar -C ${OPENWEBUI_UPLOADS} -xvf - || true"
    run "docker exec ${LOCAL_CID} sh -c 'test -d /app/db' && docker exec ${LOCAL_CID} tar -C /app -cf - db | tar -C ${OPENWEBUI_DB} -xvf - || true"
    run "docker exec ${LOCAL_CID} sh -c 'test -d /app/hal_memory' && docker exec ${LOCAL_CID} tar -C /app -cf - hal_memory | tar -C ${HAL_MEMORY} -xvf - || true"
  else
    log "Using volumes: copying into a temporary container that mounts the volumes, then extracting into them."
    # create a temporary helper container to copy into volumes
    run "docker run --rm -v ${VOL_MODELS}:/dst/models -v ${VOL_CACHE}:/dst/cache -v ${VOL_UPLOADS}:/dst/uploads -v ${VOL_DB}:/dst/db -v ${VOL_HAL_MEMORY}:/dst/hal_memory --name tmp_copy_busybox busybox true || true"
    # If local container exists, copy via tar over docker exec -> docker run cp; best-effort omitted in dry-run
    log "Note: copying into named volumes requires a helper container; perform manual copy if needed."
  fi
else
  log "No local OpenWebUI container found to copy from; skip automatic copy. You can manually copy files from any node that has the data."
fi

# -------------------------
# Step 4: update OpenWebUI service to mount persistent storage
# -------------------------
log "Updating ${OPENWEBUI_SERVICE} to mount persistent storage and set envs."

if [ "${USE_VOLUMES}" = true ]; then
  run "docker service update \
    --mount-add type=volume,src=${VOL_MODELS},dst=/root/.cache/openwebui/models \
    --mount-add type=volume,src=${VOL_CACHE},dst=/root/.cache/openwebui/cache \
    --mount-add type=volume,src=${VOL_UPLOADS},dst=/app/uploads \
    --mount-add type=volume,src=${VOL_DB},dst=/app/db \
    --mount-add type=volume,src=${VOL_HAL_MEMORY},dst=/app/hal_memory \
    --env-add OPENWEBUI_MODELS_DIR=/root/.cache/openwebui/models \
    --env-add OPENWEBUI_UPLOADS_DIR=/app/uploads \
    --env-add HAL_MEMORY_PATH=/app/hal_memory \
    --force \
    ${OPENWEBUI_SERVICE}"
else
  run "docker service update \
    --mount-add type=bind,src=${OPENWEBUI_MODELS},dst=/root/.cache/openwebui/models \
    --mount-add type=bind,src=${OPENWEBUI_CACHE},dst=/root/.cache/openwebui/cache \
    --mount-add type=bind,src=${OPENWEBUI_UPLOADS},dst=/app/uploads \
    --mount-add type=bind,src=${OPENWEBUI_DB},dst=/app/db \
    --mount-add type=bind,src=${HAL_MEMORY},dst=/app/hal_memory \
    --env-add OPENWEBUI_MODELS_DIR=/root/.cache/openwebui/models \
    --env-add OPENWEBUI_UPLOADS_DIR=/app/uploads \
    --env-add HAL_MEMORY_PATH=/app/hal_memory \
    --force \
    ${OPENWEBUI_SERVICE}"
fi

# -------------------------
# Step 5: optional Postgres deployment for HAL memory
# -------------------------
if [ "${DEPLOY_POSTGRES}" = true ]; then
  log "Deploying Postgres service ${POSTGRES_SERVICE} with volume ${POSTGRES_VOLUME}..."
  run "docker volume create --name ${POSTGRES_VOLUME} || true"
  run "docker service create --name ${POSTGRES_SERVICE} \
    --env POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    --env POSTGRES_USER=${POSTGRES_USER} \
    --env POSTGRES_DB=${POSTGRES_DB} \
    --mount type=volume,src=${POSTGRES_VOLUME},dst=/var/lib/postgresql/data \
    --replicas 1 \
    postgres:15"
  log "Updating OpenWebUI service to use Postgres connection string..."
  run "docker service update --env-add HAL_DB_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_SERVICE}:5432/${POSTGRES_DB} --force ${OPENWEBUI_SERVICE}"
else
  log "Postgres deployment skipped."
fi

# -------------------------
# Step 6: create docker config for router routing.yaml (optional)
# -------------------------
ROUTER_CONFIG_SRC="/opt/hal/config/router/routing.yaml"
if [ -f "${ROUTER_CONFIG_SRC}" ]; then
  log "Creating docker config hal_router_config from ${ROUTER_CONFIG_SRC} (if not exists)..."
  # create only if not exists
  if ! docker config ls --format '{{.Name}}' | grep -xq hal_router_config; then
    run "docker config create hal_router_config ${ROUTER_CONFIG_SRC}"
  else
    log "docker config hal_router_config already exists; skipping create."
  fi
  log "Mounting config into router service (router_hal-router)..."
  run "docker service update --config-add source=hal_router_config,target=/etc/hal/routing.yaml --force router_hal-router || true"
else
  log "Router config ${ROUTER_CONFIG_SRC} not found; skipping docker config creation."
fi

# -------------------------
# Step 7: final instructions and verification commands
# -------------------------
log "Migration steps completed (or simulated in dry-run). Now verify and adjust as needed."

cat <<EOF

Verification checklist and commands (run on manager or the node hosting the task):

1) Confirm persistent storage exists:
   # host bind mounts
   ls -la ${HOST_BASE}
   # or named volumes
   docker volume ls | grep hal_openwebui || true

2) Confirm service mounts:
   docker service inspect ${OPENWEBUI_SERVICE} --format '{{json .Spec.TaskTemplate.ContainerSpec.Mounts}}' | jq .

3) Exec into the running OpenWebUI task (on the node where it runs) and check files:
   docker service ps --filter "desired-state=running" --no-trunc ${OPENWEBUI_SERVICE}
   # on the node shown:
   docker ps --format '{{.ID}} {{.Names}} {{.Image}}' | grep openwebui_openwebui
   CID=<task_container_id>
   docker exec -it \$CID sh -c 'ls -l /root/.cache/openwebui/models || true; ls -l /app/uploads || true; ls -l /app/db || true; ls -l /app/hal_memory || true'

4) Router + routing check:
   export TOKEN=\$(docker exec ${ROUTER_CID} sh -c 'cat /run/secrets/hal_router_token' 2>/dev/null || true)
   curl -sS -H "Authorization: Bearer \$TOKEN" "http://${ROUTER_IP}:9000/openai/models" | jq .
   curl -sS -H "Authorization: Bearer \$TOKEN" "http://${ROUTER_IP}:9000/routing/why?model=deepseek-coder:6.7b" | jq .

5) If you deployed Postgres:
   docker service ps --no-trunc ${POSTGRES_SERVICE}
   docker service logs ${POSTGRES_SERVICE} --tail 200 -f

6) Backups:
   tar -czf /root/hal_openwebui_backup_\$(date +%F).tgz -C ${HOST_BASE} openwebui hal_memory

EOF

log "Done. If you want, run this script again without --dry-run to apply changes. If you want me to run a tailored non-dry run script with different paths or to include automatic backup and rollback steps, tell me and I'll produce it."
