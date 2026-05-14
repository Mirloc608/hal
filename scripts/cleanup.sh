#!/bin/bash
set -e

echo "→ Cleaning HAL directory"

find /opt/hal -type f \( -name "*.bak" -o -name "*.bak2" -o -name "*.old" -o -name "*.tmp" \) -delete
find /opt/hal -type d -name "__pycache__" -exec rm -rf {} +

rm -f /opt/hal/agent/planner.py
rm -f /opt/hal/agent/tool_executor.py

echo "✔ HAL directory cleaned"
