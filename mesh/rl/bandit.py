# hal@ai-srv:/srv/hal/mesh/rl/bandit.py

import math
import random
from collections import defaultdict


class SoftmaxBandit:
    """
    Lightweight softmax contextual bandit for node selection.
    Keeps running weights per node and updates online.
    """

    def __init__(self, temperature: float = 1.0, decay: float = 0.95):
        self.temperature = temperature
        self.decay = decay
        self.weights = defaultdict(float)
        self.counts = defaultdict(int)

    def _softmax(self, scores):
        max_s = max(scores) if scores else 0.0
        exp_vals = [math.exp((s - max_s) / self.temperature) for s in scores]
        total = sum(exp_vals) or 1.0
        return [e / total for e in exp_vals]

    def select(self, nodes):
        if not nodes:
            return None

        scores = [self.weights[n] for n in nodes]
        probs = self._softmax(scores)

        return random.choices(nodes, weights=probs, k=1)[0]

    def update(self, node, reward: float):
        """
        Online update with exponential decay.
        """
        self.weights[node] = (
            self.weights[node] * self.decay
            + reward * (1.0 - self.decay)
        )
        self.counts[node] += 1

    def get_weights(self):
        return dict(self.weights)
