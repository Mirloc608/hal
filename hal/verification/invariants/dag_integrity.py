"""Invariant checks for DAG-like execution plans."""

def validate_dag(nodes, edges):
    node_set = set(nodes)
    return all(a in node_set and b in node_set for a,b in edges)
