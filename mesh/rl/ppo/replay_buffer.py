import redis
import json
import time


class ReplayBuffer:
    """
    Swarm-shared experience store (distributed learning memory)
    """

    def __init__(self, host="redis"):
        self.r = redis.Redis(host=host, port=6379, decode_responses=True)

    def push(self, experience: dict):
        experience["ts"] = time.time()
        self.r.lpush("ppo:buffer", json.dumps(experience))

    def sample(self, n=64):
        items = self.r.lrange("ppo:buffer", 0, n)
        return [json.loads(x) for x in items]
