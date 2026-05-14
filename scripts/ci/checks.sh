#!/usr/bin/env bash
set -euo pipefail

VERBOSE=${VERBOSE:-0}

ensure_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    if [ "${CI:-}" = "true" ]; then
      echo "ERROR: required command '$1' not found in CI environment"
      exit 2
    fi
    echo "Warning: '$1' not found. Attempting to install (local only)."
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y "$2"
    else
      echo "Please install $1 (package: $2) and re-run."
      exit 2
    fi
  fi
}

files=$(git ls-files 'scripts/*.sh' || true)
if [ -n "$files" ]; then
  ensure_cmd shellcheck shellcheck
  echo "→ Running shellcheck on: $files"
  shellcheck -x $files
else
  echo "→ No shell scripts found to lint"
fi

if [ -n "$files" ]; then
  ensure_cmd shfmt shfmt
  echo "→ Checking formatting with shfmt (diff mode)"
  shfmt -d $files
else
  echo "→ No shell scripts found to format-check"
fi

if [ -d "tests" ]; then
  ensure_cmd bats bats
  echo "→ Running bats tests in ./tests"
  find tests -name '*.bats' -print | xargs -r bats
else
  echo "→ No tests directory found; skipping bats"
fi

echo "✔ Local CI checks complete"
