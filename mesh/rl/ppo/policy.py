import torch
import torch.nn.functional as F
import random
import numpy as np

from mesh.rl.ppo.model import PPOPolicyNet
from mesh.rl.ppo.encoder import FeatureEncoder


class PPOPolicy:
    """
    Runtime inference policy (NO training here).
    Training happens in separate worker.
    """

    def __init__(self):
        self.model = PPOPolicyNet()
        self.encoder = FeatureEncoder()

        self.model.eval()

    def select(self, nodes, task):
        if not nodes:
            raise RuntimeError("No nodes available")

        features = []
        for n in nodes:
            features.append(self.encoder.encode(n, task))

        x = torch.tensor(np.stack(features))

        with torch.no_grad():
            logits, values = self.model(x)
            probs = torch.softmax(logits.squeeze(), dim=0)

        idx = torch.multinomial(probs, 1).item()

        return nodes[idx], probs[idx].item()
