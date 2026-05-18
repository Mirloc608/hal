# hal@ai-srv:/srv/hal/mesh/rl/reward.py

def compute_reward(latency, success, load_penalty):
    if not success:
        return -1.0

    reward = 1.0 - latency
    reward -= load_penalty * 0.3

    return reward

    if metrics is None:
        return -1.0

    success = 1.0 if metrics.get("success", False) else 0.0
    latency = metrics.get("latency_ms", 1000.0) / 1000.0  # normalize
    error = 1.0 if metrics.get("error", False) else 0.0

    cpu_load = metrics.get("cpu_load", 0.5)
    gpu_load = metrics.get("gpu_load", 0.5)

    overload_penalty = max(cpu_load, gpu_load) * 0.5

    reward = (
        (1.0 * success)
        - (0.6 * latency)
        - (0.4 * error)
        - (0.3 * overload_penalty)
    )

    return float(reward)
