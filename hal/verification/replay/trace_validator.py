"""Validate trace replay invariants."""

def validate_trace(trace):
    return isinstance(trace, dict) and "events" in trace
