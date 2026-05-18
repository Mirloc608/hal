import numpy as np


class FeatureEncoder:
    """
    Converts Swarm node + task state → tensor features
    """

    def encode(self, node: dict, task: dict):
        return np.array([
            float(node.get("labels", {}).get("gpu", 0)),
            float(node.get("labels", {}).get("cpu", 0)),
            float(task.get("load", 1)),
            float(task.get("latency_sensitive", 0)),
            float(task.get("type", "llm") == "llm"),
            float(task.get("type", "rag") == "rag"),
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
        ], dtype=np.float32)
