import numpy as np

class PPOLoss:
    def __init__(self, epsilon=0.2):
        self.epsilon = epsilon

    def compute(self, logp_new, logp_old, advantages):
        ratio = np.exp(logp_new - logp_old)

        clipped = np.clip(ratio, 1 - self.epsilon, 1 + self.epsilon) * advantages
        unclipped = ratio * advantages

        return -np.mean(np.minimum(clipped, unclipped))
