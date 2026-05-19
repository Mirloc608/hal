"""Batch validation for rollout packets."""

def validate_batch(batch):
    if not isinstance(batch, (list, tuple)):
        raise TypeError("batch must be list/tuple")
    return True
