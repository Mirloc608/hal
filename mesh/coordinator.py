import requests
import time
from mesh.router import MeshRouter


class MeshCoordinator:

    def __init__(self):
        self.router = MeshRouter()

    def route_request(self, payload: dict):
        node, prob = self.router.select_node(payload)

        target = f"http://hal-{node['labels'].get('role','gpu')}:7300/chat"

        start = time.time()

        try:
            res = requests.post(target, json=payload, timeout=10)
            latency = time.time() - start

            reward = 1.0 / max(latency, 0.01)

            self.router.report_reward(
                node=node,
                task=payload,
                reward=reward,
                action=node["id"],
                logprob=prob
            )

            return res.json()

        except Exception:
            self.router.report_reward(
                node=node,
                task=payload,
                reward=-1.0,
                action=node["id"],
                logprob=prob
            )
            raise
