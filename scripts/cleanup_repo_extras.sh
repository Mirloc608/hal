#!/usr/bin/env bash
set -euo pipefail

# HAL housekeeping: remove transient/local development artifacts.
find . -type d -name '__pycache__' -prune -exec rm -rf {} +
find . -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.log' -o -name '.DS_Store' \) -delete
rm -rf .pytest_cache .mypy_cache .ruff_cache

echo "Repository transient artifacts cleaned."
