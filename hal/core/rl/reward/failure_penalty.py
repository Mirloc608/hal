"""Failure penalties for unsafe/invalid outcomes."""

def apply_failure_penalty(reward: float, failed: bool, penalty: float = 1.0) -> float:
    return reward - penalty if failed else reward
