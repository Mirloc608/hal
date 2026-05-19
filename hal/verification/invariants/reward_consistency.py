"""Invariant checks for reward consistency."""

def validate_reward_consistency(rewards):
    return all(r is not None for r in rewards)
