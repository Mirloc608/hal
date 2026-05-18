import requests
import torch

class DistributedSync:
    def __init__(self, learner_urls):
        self.learner_urls = learner_urls

    def broadcast_weights(self, model):
        state = model.state_dict()
        payload = {k: v.cpu().tolist() for k, v in state.items()}

        for url in self.learner_urls:
            try:
                requests.post(f"{url}/sync_weights", json=payload, timeout=2)
            except:
                pass

    def pull_latest(self, model, url):
        try:
            r = requests.get(f"{url}/latest_weights", timeout=2)
            state = r.json()

            new_state = {k: torch.tensor(v) for k, v in state.items()}
            model.load_state_dict(new_state)
        except:
            pass
