#!/usr/bin/env bash
set -euo pipefail

# Removes legacy modules after migration to hal/* namespace.
rm -f mesh/rl/ppo_agent.py mesh/rl/ppo_policy.py mesh/rl/ppo_trainer.py mesh/rl/reward.py mesh/rl/router_policy.py mesh/rl/rollout_buffer.py mesh/telemetry.py mesh/router.py mesh/coordinator.py
rm -f governance/service.py core/router/llm_router.py core/mcp/mcp_server.py gateway/main.py nodes/gpu/infer.py nodes/cpu/control.py

echo "Legacy layout files removed."
