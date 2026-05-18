import json
import requests
import redis
import json

r = redis.Redis(host="redis", port=6379)


class DistributedPolicyMemory:
    """
    Shared routing intelligence across nodes.
    """

    def __init__(self, memory_endpoint="http://hal-memory:7304/policy"):
        self.endpoint = memory_endpoint

    def push_update(self, node, reward, metadata):
        payload = {
            "node": node,
            "reward": reward,
            "meta": metadata
        }

        try:
            requests.post(self.endpoint + "/update", json=payload, timeout=0.2)
        except Exception:
            pass

    def pull_policy(self):
        try:
            r = requests.get(self.endpoint + "/snapshot", timeout=0.2)
            return r.json()
        except Exception:
            return {}

    def write_experience(obs, action, reward):
        r.rpush("hal:experience",
                json.dumps([obs, action, reward]))

    def sample_experience(n=32):
        items = r.lrange("hal:experience", 0, n)
        return [json.loads(i) for i in items]
