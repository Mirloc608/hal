import numpy as np

class GAE:
    def __init__(self, gamma=0.99, lam=0.95):
        self.gamma = gamma
        self.lam = lam

    def compute(self, rewards, values):
        advantages = np.zeros_like(rewards)
        last_adv = 0

        for t in reversed(range(len(rewards))):
            next_value = values[t+1] if t+1 < len(values) else 0
            delta = rewards[t] + self.gamma * next_value - values[t]
            last_adv = delta + self.gamma * self.lam * last_adv
            advantages[t] = last_adv

        returns = advantages + values[:len(advantages)]
        return advantages, returns
