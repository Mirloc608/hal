#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/push-images.sh <TAG> [--push-external]
# Example: ./scripts/push-images.sh 20260514-101500
#
# Behavior:
# - Scans stacks/*.yml.tpl for "image:" lines
# - Replaces @@TAG@@, ${TAG}, ${TAG}-style, and {{HAL_TAG}} with provided TAG
# - Skips images that already have a fixed tag (e.g., :latest, :v2.54.0) unless --push-external is passed
# - Assumes local images are named by the basename (last path component) and tagged with TAG
# - Tags local image -> registry.dmathome.com/<basename>:TAG and pushes it

REGISTRY="registry.dmathome.com"
TAG="${1:-}"
PUSH_EXTERNAL=false
TEMPLATE_GLOB="stacks/*.yml.tpl"

if [ -z "$TAG" ]; then
  echo "Usage: $0 <TAG> [--push-external]"
  exit 1
fi

if [ "${2:-}" = "--push-external" ]; then
  PUSH_EXTERNAL=true
fi

echo "Logging into ${REGISTRY}"
docker login "${REGISTRY}" -u registryuser

# Gather image lines
images_raw=$(grep -hE '^[[:space:]]*image:[[:space:]]*' ${TEMPLATE_GLOB} 2>/dev/null || true)
if [ -z "$images_raw" ]; then
  echo "No image lines found in ${TEMPLATE_GLOB}"
  exit 0
fi

# Normalize and dedupe image tokens
images=$(printf "%s\n" "${images_raw}" \
  | sed -E 's/^[[:space:]]*image:[[:space:]]*//g' \
  | sed -E 's/["'\'']//g' \
  | sed -E 's/[[:space:]]+$//g' \
  | sort -u)

echo "Found image entries in templates:"
printf "  %s\n" ${images}

for img in ${images}; do
  # Replace known token forms with TAG
  dst="$img"
  dst="${dst//@@TAG@@/${TAG}}"
  dst="${dst//\$\{TAG\}/${TAG}}"
  dst="${dst//\$\{[A-Za-z_][A-Za-z0-9_]*\}/${TAG}}"   # generic ${...} -> TAG
  dst="$(echo "$dst" | sed -E "s/\{\{[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\}\}/${TAG}/g")" # {{HAL_TAG}} -> TAG

  # If destination already has a non-empty explicit tag (e.g., :latest or :v2.54.0)
  if echo "$dst" | grep -qE ':[^/:]+$'; then
    explicit_tag="$(echo "$dst" | sed -E 's/.*:([^/:]+)$/\1/')"
    # If explicit tag looks like a variable placeholder (still contains $ or @ or {), treat as not explicit
    if echo "$explicit_tag" | grep -qE '(\$|@|\{|\})'; then
      explicit_tag=""
    fi
  else
    explicit_tag=""
  fi

  # Decide whether to push this image
  if [ -n "$explicit_tag" ] && [ "$PUSH_EXTERNAL" = "false" ]; then
    echo "Skipping external image with explicit tag: $dst"
    continue
  fi

  # Determine local source image name
  # If template used registry host, assume local image is basename:TAG
  base="$(basename "$img")"
  src="${base%:*}:${TAG}"

  # If the template already points to registry host, set dst accordingly (replace token)
  if echo "$dst" | grep -qE "^${REGISTRY}/"; then
    final_dst="$dst"
  else
    # If dst already contains a registry (other than ours), push only if --push-external
    if echo "$dst" | grep -qE '^[^/]+/'; then
      # contains a registry or namespace; if it already contains our registry, keep; else prefix our registry
      if echo "$dst" | grep -qE "^${REGISTRY}/"; then
        final_dst="$dst"
      else
        # default: push to our registry under basename
        final_dst="${REGISTRY}/${base%:*}:${TAG}"
      fi
    else
      final_dst="${REGISTRY}/${base%:*}:${TAG}"
    fi
  fi

  echo
  echo "Processing:"
  echo "  template token : $img"
  echo "  resolved dst   : $final_dst"
  echo "  local src      : $src"

  # Ensure local image exists
  if ! docker image inspect "${src}" >/dev/null 2>&1; then
    echo "ERROR: Local image ${src} not found. Build or tag it first."
    exit 1
  fi

  # Tag and push
  docker tag "${src}" "${final_dst}"
  docker push "${final_dst}"
done

echo
echo "All requested images processed and pushed to ${REGISTRY} with tag ${TAG}"
