import time

def build_obs(node_state, mesh_state):
    """
    Converts HAL swarm into RL state vector.
    THIS is what PPO actually learns from.
    """

    return [
        node_state.get("cpu", 0),
        node_state.get("gpu", 0),
        node_state.get("mem", 0),

        mesh_state.get("avg_latency", 0),
        mesh_state.get("error_rate", 0),
        mesh_state.get("queue_depth", 0),

        mesh_state.get("active_nodes", 1),
        mesh_state.get("failed_nodes", 0),

        time.time() % 1000  # temporal signal (important for PPO stability)
    ]
