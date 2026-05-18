import subprocess
from mesh.rl.reward import compute_reward

FAILURE_THRESHOLD = -0.5

class SelfHealer:

    def __init__(self):
        self.recent_reward = 0

    def update_reward(self, reward):
        self.recent_reward = reward

        if self.recent_reward < FAILURE_THRESHOLD:
            self.trigger_heal()

    def trigger_heal(self):
        subprocess.run(["docker", "restart", "hal-mesh"])
        subprocess.run(["docker", "restart", "hal-gateway"])
