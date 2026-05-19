"""Edge cost functions for mesh planning."""

def compute_edge_cost(latency_ms: float, error_rate: float, weight_latency: float = 1.0, weight_error: float = 10.0):
    return latency_ms * weight_latency + error_rate * weight_error
