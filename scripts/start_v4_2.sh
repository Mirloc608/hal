#!/bin/bash

echo "=================================="
echo " HAL v4.2 STARTUP (DEV MODE)"
echo "=================================="

export PYTHONPATH=/opt/hal

echo "[1] Starting MCP server..."
python3 /opt/hal/core/mcp/mcp_server.py &

echo "[2] Starting VSCode bridge..."
python3 /opt/hal/services/vscode_bridge.py &

echo "[3] Starting Gateway..."
python3 /opt/hal/gateway/main.py &

echo "[4] System boot complete"
wait
