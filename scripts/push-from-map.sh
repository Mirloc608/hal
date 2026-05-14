#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
MAP_FILE="image-map.txt"
REGISTRY_USER="${REGISTRY_USER:-registryuser}"

if [ -z "$TAG" ]; then
  echo "Usage: $0 <TAG>"
  exit 1
fi
if [ ! -f "$MAP_FILE" ]; then
  echo "Missing $MAP_FILE"
  exit 1
fi

echo "Logging into registry.dmathome.com as ${REGISTRY_USER}"
docker login registry.dmathome.com -u "${REGISTRY_USER}"

while IFS=: read -r local dst; do
  case "$local" in
    ''|\#*) continue ;;
  esac
  local_trimmed="$(echo "$local" | xargs)"
  dst_trimmed="$(echo "$dst" | xargs)"
  src="${local_trimmed}:${TAG}"
  dst_full="${dst_trimmed}:${TAG}"

  echo
  echo "Processing: ${local_trimmed} -> ${dst_trimmed} (tag ${TAG})"
  echo "  local src : ${src}"
  echo "  registry dst : ${dst_full}"

  if ! docker image inspect "${src}" >/dev/null 2>&1; then
    echo "ERROR: local image ${src} not found. Build it first."
    exit 2
  fi

  docker tag "${src}" "${dst_full}"
  docker push "${dst_full}"
done < "$MAP_FILE"

echo
echo "All images pushed with tag ${TAG}"
