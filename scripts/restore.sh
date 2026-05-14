#!/usr/bin/env bash
set -euo pipefail

# Usage: restore.sh --file /path/to/backup.tar.gz [--yes] [--dry-run|-n] [--verbose|-v]

DOCKER_CMD=${DOCKER_CMD:-docker}
HAL_ROOT=${HAL_ROOT:-/opt/hal}
BACKUP_FILE=""
CONFIRM=0
DRY_RUN=0
VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --file) BACKUP_FILE="$2"; shift 2 ;;
    --yes) CONFIRM=1; shift ;;
    --dry-run|-n) DRY_RUN=1; shift ;;
    --verbose|-v) VERBOSE=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

if [ -z "$BACKUP_FILE" ]; then
  echo "ERROR: --file is required"
  exit 1
fi
if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: backup file not found: $BACKUP_FILE"
  exit 2
fi

echo "Restore: BACKUP_FILE=$BACKUP_FILE HAL_ROOT=$HAL_ROOT"
[ "$VERBOSE" -eq 1 ] && echo "DRY_RUN=$DRY_RUN CONFIRM=$CONFIRM"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: would extract $BACKUP_FILE and restore DBs if --yes provided"
  exit 0
fi

if [ "$CONFIRM" -ne 1 ]; then
  echo "Destructive restore requires --yes"
  exit 3
fi

TMPDIR="$(mktemp -d)"
tar -xzf "$BACKUP_FILE" -C "$TMPDIR" || { echo "extract failed"; rm -rf "$TMPDIR"; exit 4; }

if [ -f "$TMPDIR/ke.sql" ]; then
  KE_CONTAINER="$($DOCKER_CMD ps -qf 'name=postgres-ke' 2>/dev/null || true)"
  if [ -n "$KE_CONTAINER" ]; then
    $DOCKER_CMD exec -i "$KE_CONTAINER" psql -U ke_user ke < "$TMPDIR/ke.sql" || echo "KE restore failed"
  else
    echo "postgres-ke not found; skipping KE restore"
  fi
fi

if [ -f "$TMPDIR/planner.sql" ]; then
  PL_CONTAINER="$($DOCKER_CMD ps -qf 'name=planner-db' 2>/dev/null || true)"
  if [ -n "$PL_CONTAINER" ]; then
    $DOCKER_CMD exec -i "$PL_CONTAINER" psql -U planner_user planner < "$TMPDIR/planner.sql" || echo "Planner restore failed"
  else
    echo "planner-db not found; skipping Planner restore"
  fi
fi

cp -r "$TMPDIR/stacks" "$HAL_ROOT/" 2>/dev/null || echo "stacks copy failed"
cp -r "$TMPDIR/config" "$HAL_ROOT/router/" 2>/dev/null || true
cp -r "$TMPDIR/ke" "$HAL_ROOT/" 2>/dev/null || true
cp -r "$TMPDIR/planner" "$HAL_ROOT/agent/" 2>/dev/null || true

rm -rf "$TMPDIR"
echo "✔ Restore complete"
