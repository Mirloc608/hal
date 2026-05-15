#!/usr/bin/env bash
set -euo pipefail

VERBOSE=${VERBOSE:-0}

ensure_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    if [ "${CI:-}" = "true" ]; then
      echo "ERROR: required command '$1' not found in CI environment"
      exit 2
    fi
    echo "Warning: '$1' not found. Attempting to install local package $2."
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y "$2"
    else
      echo "Please install $1 (package: $2) and re-run."
      exit 2
    fi
  fi
}

files=$(git ls-files 'scripts/*.sh' || true)

# Ensure tools we will use
ensure_cmd shellcheck shellcheck
ensure_cmd shfmt shfmt
ensure_cmd bats bats
ensure_cmd bats bats
ensure_cmd bats bats
ensure_cmd bats bats

if [ -n "$files" ]; then
  echo "→ Running shellcheck on: $files"
  echo "$files" | xargs -r shellcheck -x

  echo "→ Checking formatting with shfmt (diff mode)"
  echo "$files" | xargs -r shfmt -d
else
  echo "No shell scripts found to lint/format"
fi

if [ -d "tests" ]; then
  echo "→ Running bats tests (if any)"
  find tests -name '*.bats' -print0 | xargs -0 -r bats
else
  echo "No tests directory found; skipping bats"
fi

echo "✔ Local CI checks complete"
