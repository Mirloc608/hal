#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="${1:-stacks}"
MISSING=0

echo "Stack linter scanning ${STACK_DIR} for missing TAG placeholders and unset env vars..."

for f in "${STACK_DIR}"/*.yml "${STACK_DIR}"/*.yaml; do
  [ -f "$f" ] || continue
  echo "→ linting $f"
  if grep -q ':TAG' "$f"; then
    echo "  ✖ Found literal :TAG in $f"
    MISSING=1
  fi

  # Find ${VAR} occurrences and check uppercase vars
  grep -Eo '\$\{[A-Z_][A-Z0-9_]+\}' "$f" | sort -u | while read -r v; do
    [ -z "$v" ] && continue
    varname=$(echo "$v" | sed 's/[^A-Z0-9_]//g')
    if [ -z "${!varname:-}" ]; then
      echo "  ✖ Unset env var $varname referenced in $f"
      MISSING=1
    fi
  done
done

if [ "$MISSING" -ne 0 ]; then
  echo "Stack linter found issues"
  exit 2
fi

echo "Stack linter OK"
