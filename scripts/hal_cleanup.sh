#!/usr/bin/env bash
set -euo pipefail

# HAL full cleanup script
# Goal:
#   /opt/hal  -> source only
#   /srv/hal  -> runtime only

OPT_HAL="/opt/hal"
SRV_HAL="/srv/hal"

echo "=== HAL CLEANUP START ==="
echo "OPT_HAL=${OPT_HAL}"
echo "SRV_HAL=${SRV_HAL}"
echo

confirm() {
  read -r -p "$1 [y/N]: " ans
  case "$ans" in
    [Yy]*) return 0 ;;
    *)     return 1 ;;
  esac
}

mkdir -p "${SRV_HAL}"

########################################
# 1. Move any potentially useful data out of /opt/hal/data
########################################
echo ">>> Phase 1: Handle /opt/hal/data runtime artifacts"

# Ensure target dirs exist
mkdir -p "${SRV_HAL}/grafana"
mkdir -p "${SRV_HAL}/config/openwebui"
mkdir -p "${SRV_HAL}/qdrant"
mkdir -p "${SRV_HAL}/ollama"
mkdir -p "${SRV_HAL}/logs"

# If any of these exist, move them once, then we’ll delete /opt copies
move_if_exists() {
  local src="$1"
  local dst="$2"
  if [ -e "$src" ]; then
    echo "  - Moving $src -> $dst"
    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
  else
    echo "  - Skipping $src (not present)"
  fi
}

# Grafana data (csv/png/unified-search) -> /srv/hal/grafana
move_if_exists "${OPT_HAL}/data/grafana/csv"            "${SRV_HAL}/grafana/csv"
move_if_exists "${OPT_HAL}/data/grafana/png"            "${SRV_HAL}/grafana/png"
move_if_exists "${OPT_HAL}/data/grafana/unified-search" "${SRV_HAL}/grafana/unified-search"

# OpenWebUI data -> /srv/hal/config/openwebui (if somehow still under /opt)
move_if_exists "${OPT_HAL}/data/openwebui" "${SRV_HAL}/config/openwebui/legacy_migrated"

# Qdrant data -> /srv/hal/qdrant (if somehow still under /opt)
move_if_exists "${OPT_HAL}/data/qdrant" "${SRV_HAL}/qdrant/legacy_migrated"

# Ollama data -> /srv/hal/ollama (if somehow still under /opt)
move_if_exists "${OPT_HAL}/data/ollama" "${SRV_HAL}/ollama/legacy_migrated"

# HAL memory (if you care to keep it)
move_if_exists "${OPT_HAL}/data/hal_memory" "${SRV_HAL}/hal_memory"

echo

########################################
# 2. Delete runtime data directories from /opt/hal
########################################
echo ">>> Phase 2: Delete runtime data from /opt/hal"

if [ -d "${OPT_HAL}/data" ]; then
  echo "  - About to remove ${OPT_HAL}/data (runtime-only now)"
  if confirm "    Remove ${OPT_HAL}/data entirely?"; then
    rm -rf "${OPT_HAL}/data"
    echo "  - Removed ${OPT_HAL}/data"
  else
    echo "  - Skipped removing ${OPT_HAL}/data"
  fi
else
  echo "  - ${OPT_HAL}/data not present, skipping"
fi

echo

########################################
# 3. Canonicalize router configs to /srv/hal/config/router
########################################
echo ">>> Phase 3: Canonicalize router configs"

ROUTER_CFG_SRV="${SRV_HAL}/config/router"
mkdir -p "${ROUTER_CFG_SRV}"

# If /opt/hal/config/router/routing.yaml exists, move it once then delete dir
if [ -d "${OPT_HAL}/config/router" ]; then
  echo "  - Found ${OPT_HAL}/config/router, migrating any configs"
  for f in classifier.yaml model_tools.yaml router.yaml routes.yaml tools.yaml routing.yaml; do
    if [ -f "${OPT_HAL}/config/router/${f}" ]; then
      echo "    - Moving ${f} -> ${ROUTER_CFG_SRV}/${f}.opt_legacy"
      mv "${OPT_HAL}/config/router/${f}" "${ROUTER_CFG_SRV}/${f}.opt_legacy"
    fi
  done
  if confirm "    Remove ${OPT_HAL}/config/router directory?"; then
    rm -rf "${OPT_HAL}/config/router"
    echo "    - Removed ${OPT_HAL}/config/router"
  else
    echo "    - Skipped removing ${OPT_HAL}/config/router"
  fi
else
  echo "  - ${OPT_HAL}/config/router not present, skipping"
fi

# Router local config under /opt/hal/router/config
if [ -d "${OPT_HAL}/router/config" ]; then
  echo "  - Found ${OPT_HAL}/router/config, migrating any configs"
  for f in classifier.yaml model_tools.yaml router.yaml routes.yaml tools.yaml; do
    if [ -f "${OPT_HAL}/router/config/${f}" ]; then
      echo "    - Moving ${f} -> ${ROUTER_CFG_SRV}/${f}.router_legacy"
      mv "${OPT_HAL}/router/config/${f}" "${ROUTER_CFG_SRV}/${f}.router_legacy"
    fi
  done
  if confirm "    Remove ${OPT_HAL}/router/config directory?"; then
    rm -rf "${OPT_HAL}/router/config"
    echo "    - Removed ${OPT_HAL}/router/config"
  else
    echo "    - Skipped removing ${OPT_HAL}/router/config"
  fi
else
  echo "  - ${OPT_HAL}/router/config not present, skipping"
fi

echo

########################################
# 4. Consolidate Grafana dashboards under /srv/hal/config/monitoring/grafana/dashboards
########################################
echo ">>> Phase 4: Consolidate Grafana dashboards"

GRAFANA_DASH_DIR="${SRV_HAL}/config/monitoring/grafana/dashboards"
mkdir -p "${GRAFANA_DASH_DIR}"

# Helper: move dashboards from a source dir if it exists
move_dashboards() {
  local src="$1"
  if [ -d "$src" ]; then
    echo "  - Moving dashboards from $src -> ${GRAFANA_DASH_DIR}"
    find "$src" -maxdepth 1 -type f -name '*.json' -print0 | while IFS= read -r -d '' f; do
      echo "    - $(basename "$f")"
      mv "$f" "${GRAFANA_DASH_DIR}/"
    done
  else
    echo "  - No dashboards at $src"
  fi
}

move_dashboards "${OPT_HAL}/agent/planner/grafana"
move_dashboards "${OPT_HAL}/monitoring/grafana/dashboards"
move_dashboards "${OPT_HAL}/ke/grafana"

# Optionally remove now-empty dirs
for d in \
  "${OPT_HAL}/agent/planner/grafana" \
  "${OPT_HAL}/monitoring/grafana/dashboards" \
  "${OPT_HAL}/ke/grafana"
do
  if [ -d "$d" ]; then
    if confirm "    Remove empty/legacy Grafana dir $d?"; then
      rm -rf "$d"
      echo "    - Removed $d"
    else
      echo "    - Kept $d"
    fi
  fi
done

echo

########################################
# 5. Canonicalize model storage to /srv/hal/ollama/models
########################################
echo ">>> Phase 5: Canonicalize model storage"

OLLAMA_MODELS_SRV="${SRV_HAL}/ollama/models"
mkdir -p "${OLLAMA_MODELS_SRV}"

# Move any /opt/hal/data/ollama/models if still present (should be gone from Phase 1)
if [ -d "${OPT_HAL}/data/ollama/models" ]; then
  echo "  - Moving ${OPT_HAL}/data/ollama/models -> ${OLLAMA_MODELS_SRV}/opt_legacy"
  mv "${OPT_HAL}/data/ollama/models" "${OLLAMA_MODELS_SRV}/opt_legacy"
fi

# /srv/hal/models -> /srv/hal/ollama/models if unique
if [ -d "${SRV_HAL}/models" ]; then
  echo "  - Found ${SRV_HAL}/models, migrating into ${OLLAMA_MODELS_SRV}/srv_models_legacy"
  mv "${SRV_HAL}/models" "${OLLAMA_MODELS_SRV}/srv_models_legacy"
fi

echo

########################################
# 6. Remove deprecated service directories under /opt/hal/services
########################################
echo ">>> Phase 6: Remove deprecated service directories"

for svc in rag router mcp-fs; do
  d="${OPT_HAL}/services/${svc}"
  if [ -d "$d" ]; then
    echo "  - Found deprecated service dir: $d"
    if confirm "    Remove $d?"; then
      rm -rf "$d"
      echo "    - Removed $d"
    else
      echo "    - Kept $d"
    fi
  else
    echo "  - $d not present, skipping"
  fi
done

echo

########################################
# 7. Prune unused docker-compose files for node1/node2
########################################
echo ">>> Phase 7: Prune unused docker-compose files for node1/node2"

for node in node1 node2; do
  dc="${OPT_HAL}/docker/${node}/docker-compose.yml"
  rmv="${OPT_HAL}/docker/${node}/remove.sh"
  if [ -f "$dc" ]; then
    echo "  - Found $dc (Swarm stacks are canonical)"
    if confirm "    Remove $dc?"; then
      rm -f "$dc"
      echo "    - Removed $dc"
    else
      echo "    - Kept $dc"
    fi
  fi
  if [ -f "$rmv" ]; then
    echo "  - Found $rmv"
    if confirm "    Remove $rmv?"; then
      rm -f "$rmv"
      echo "    - Removed $rmv"
    else
      echo "    - Kept $rmv"
    fi
  fi
done

echo

########################################
# 8. Prune legacy scripts (keep only core cluster scripts)
########################################
echo ">>> Phase 8: Prune legacy scripts"

SCRIPTS_DIR="${OPT_HAL}/scripts"
if [ -d "${SCRIPTS_DIR}" ]; then
  echo "  - Scanning ${SCRIPTS_DIR}"

  keep=(
    "bootstrap-ssh-trust.sh"
    "cluster-deploy.sh"
    "cluster-health.sh"
    "cluster-image-sync.sh"
    "cluster-redeploy.sh"
  )

  # Build a pattern of files to keep
  keep_pattern="$(printf "|%s" "${keep[@]}")"
  keep_pattern="${keep_pattern:1}"

  find "${SCRIPTS_DIR}" -maxdepth 1 -type f -name '*.sh' | while read -r f; do
    base="$(basename "$f")"
    if [[ "${keep_pattern}" =~ (^|.*\|)"${base}"(\|.*|$) ]]; then
      echo "    - Keeping ${base}"
    else
      echo "    - Legacy script: ${base}"
      if confirm "      Remove ${base}?"; then
        rm -f "$f"
        echo "      - Removed ${base}"
      else
        echo "      - Kept ${base}"
      fi
    fi
  done
else
  echo "  - ${SCRIPTS_DIR} not present, skipping"
fi

echo

########################################
# 9. Final message
########################################
echo "=== HAL CLEANUP COMPLETE (logical structure enforced) ==="
echo "Now consider running docker/prune commands on each node:"
echo "  docker system prune -af --volumes"
echo "  docker image prune -af"
echo "  docker network prune"
echo
