#!/usr/bin/env bash
set -euo pipefail

# Usage: backup.sh [--out DIR] [--tag TAG] [--dry-run|-n] [--verbose|-v]

HAL_ROOT=${HAL_ROOT:-/opt/hal}
OUT_DIR=${OUT_DIR:-}
DOCKER_CMD=${DOCKER_CMD:-docker}
TAG=${TAG:-$(date +%Y%m%d-%H%M%S)}
DRY_RUN=0
VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_DIR="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --dry-run|-n) DRY_RUN=1; shift ;;
    --verbose|-v) VERBOSE=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

OUT_DIR=${OUT_DIR:-"$HAL_ROOT/backups"}
ARCHIVE="$OUT_DIR/hal-backup-$TAG.tar.gz"
TMPDIR="$(mktemp -d)"

echo "Backup: HAL_ROOT=$HAL_ROOT OUT_DIR=$OUT_DIR TAG=$TAG"
[ "$VERBOSE" -eq 1 ] && echo "TMPDIR=$TMPDIR"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: would create $ARCHIVE and dump DBs if present"
  rm -rf "$TMPDIR"
  exit 0
fi

mkdir -p "$OUT_DIR"

KE_CONTAINER="$($DOCKER_CMD ps -qf 'name=postgres-ke' 2>/dev/null || true)"
if [ -n "$KE_CONTAINER" ]; then
  [ "$VERBOSE" -eq 1 ] && echo "Dumping KE from container $KE_CONTAINER"
  $DOCKER_CMD exec "$KE_CONTAINER" pg_dump -U ke_user ke > "$TMPDIR/ke.sql" || echo "ke dump failed"
else
  [ "$VERBOSE" -eq 1 ] && echo "No postgres-ke container found; skipping KE dump"
fi

PL_CONTAINER="$($DOCKER_CMD ps -qf 'name=planner-db' 2>/dev/null || true)"
if [ -n "$PL_CONTAINER" ]; then
  [ "$VERBOSE" -eq 1 ] && echo "Dumping Planner from container $PL_CONTAINER"
  $DOCKER_CMD exec "$PL_CONTAINER" pg_dump -U planner_user planner > "$TMPDIR/planner.sql" || echo "planner dump failed"
else
  [ "$VERBOSE" -eq 1 ] && echo "No planner-db container found; skipping Planner dump"
fi

mkdir -p "$TMPDIR/config"
cp -r "$HAL_ROOT/stacks" "$TMPDIR/" 2>/dev/null || true
cp -r "$HAL_ROOT/router/config" "$TMPDIR/config" 2>/dev/null || true
cp -r "$HAL_ROOT/ke" "$TMPDIR/" 2>/dev/null || true
cp -r "$HAL_ROOT/agent/planner" "$TMPDIR/" 2>/dev/null || true

echo "Creating archive $ARCHIVE"
tar -czf "$ARCHIVE" -C "$TMPDIR" . || { echo "tar failed"; rm -rf "$TMPDIR"; exit 3; }

rm -rf "$TMPDIR"
echo "✔ Backup complete: $ARCHIVE"
