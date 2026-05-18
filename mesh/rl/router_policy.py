import math
import time
import random
import torch
from collections import defaultdict

class RLRouterPolicy:
    def __init__(self, agent):
        self.agent = agent

    def select_node(self, obs, nodes):
        action, logprob, value = self.agent.act(obs)

        if action >= len(nodes):
            return random.choice(nodes), logprob, value

        return nodes[action], logprob, value

class RouterPolicy:
    """
    Hybrid Bandit → PPO-ready policy scaffold.

    Phase 1: exponential moving reward (bandit)
    Phase 2: plug PPO model later
    """

    def __init__(self):
        self.reward_map = defaultdict(lambda: 0.0)
        self.count_map = defaultdict(lambda: 1)

    def score(self, node: dict, features: dict) -> float:
        node_id = node["id"]

        base_reward = self.reward_map[node_id] / self.count_map[node_id]

        # simple heuristics (bootstrapping signal)
        load_penalty = 0.1 if node.get("labels", {}).get("gpu") == "true" else 0.2

        return base_reward - load_penalty

    def update(self, node_id: str, reward: float):
        self.count_map[node_id] += 1
        n = self.count_map[node_id]

        # EMA update
        self.reward_map[node_id] += (reward - self.reward_map[node_id]) / n
