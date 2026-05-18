import torch
import torch.optim as optim
from .ppo_config import PPOConfig
from .policy_network import PolicyNet

class PPOAgent:
    def __init__(self, obs_dim, action_dim):
        self.net = PolicyNet(obs_dim, action_dim)
        self.opt = optim.Adam(self.net.parameters(), lr=PPOConfig.LR)

    def act(self, obs):
        obs = torch.tensor(obs, dtype=torch.float32)
        logits, value = self.net(obs)

        dist = torch.distributions.Categorical(logits=logits)
        action = dist.sample()

        return (
            action.item(),
            dist.log_prob(action).item(),
            value.item()
        )

    def evaluate(self, obs, action):
        logits, value = self.net(obs)
        dist = torch.distributions.Categorical(logits=logits)

        logprob = dist.log_prob(action)
        entropy = dist.entropy()

        return logprob, value, entropy
