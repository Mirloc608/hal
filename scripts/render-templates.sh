#!/usr/bin/env bash
set -euo pipefail

# Usage: render-templates.sh [--tag TAG] [--hal-root PATH] [--dry-run|-n] [--verbose|-v]

HAL_ROOT=${HAL_ROOT:-/opt/hal}
STACK_DIR=${STACK_DIR:-"$HAL_ROOT/stacks"}
TAG=${TAG:-$(date +%Y%m%d-%H%M%S)}
DRY_RUN=0
VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    --hal-root) HAL_ROOT="$2"; shift 2 ;;
    --dry-run|-n) DRY_RUN=1; shift ;;
    --verbose|-v) VERBOSE=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

TEMPLATE_GLOB=${TEMPLATE_GLOB:-"$STACK_DIR/*.yml.tpl"}

[ "$VERBOSE" -eq 1 ] && echo "HAL_ROOT=$HAL_ROOT STACK_DIR=$STACK_DIR TAG=$TAG TEMPLATE_GLOB=$TEMPLATE_GLOB"

mkdir -p "$STACK_DIR"

for tpl in $TEMPLATE_GLOB; do
  [ -f "$tpl" ] || continue
  out="$STACK_DIR/$(basename "$tpl" .tpl)"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: would render $tpl -> $out"
    [ "$VERBOSE" -eq 1 ] && echo "  (would run envsubst and sed with TAG=$TAG)"
    continue
  fi
  TAG="$TAG" envsubst '${TAG}' < "$tpl" | sed "s|@@TAG@@|$TAG|g; s|{{HAL_TAG}}|$TAG|g" > "$out"
  echo "rendered $tpl -> $out"
done
