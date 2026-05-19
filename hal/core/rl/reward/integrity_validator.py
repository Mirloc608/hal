"""Validate reward payload integrity."""

def validate_reward(value):
    if value is None:
        raise ValueError("reward cannot be None")
    return float(value)
