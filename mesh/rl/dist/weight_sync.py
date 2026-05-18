import redis
import torch
import io
import time

from mesh.rl.ppo.model import PPOPolicyNet
from mesh.rl.dist.config import WEIGHTS_KEY, POLICY_VERSION_KEY


class WeightSync:
    """
    Global policy sync (Swarm shared weights)
    """

    def __init__(self):
        self.r = redis.Redis(host="redis", port=6379)
        self.model = PPOPolicyNet()
        self.version = 0

    def get_weights(self):
        raw = self.r.get(WEIGHTS_KEY)
        if not raw:
            return None

        buffer = io.BytesIO(raw)
        state = torch.load(buffer, map_location="cpu")
        self.model.load_state_dict(state)

        return self.model

    def push_weights(self, model, version: int):
        buffer = io.BytesIO()
        torch.save(model.state_dict(), buffer)

        self.r.set(WEIGHTS_KEY, buffer.getvalue())
        self.r.set(POLICY_VERSION_KEY, version)
