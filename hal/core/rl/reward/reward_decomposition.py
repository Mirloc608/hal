"""Reward decomposition primitives."""

def decompose_reward(total_reward: float, **parts):
    if parts:
        return parts
    return {"task": total_reward}
