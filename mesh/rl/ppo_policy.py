import torch
import torch.nn as nn
import torch.optim as optim
import random


class PolicyNet(nn.Module):
    def __init__(self, input_dim, output_dim):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, 64),
            nn.ReLU(),
            nn.Linear(64, output_dim),
        )

    def forward(self, x):
        return self.net(x)


class PPOPolicy:
    """
    Lightweight PPO-style policy over routing decisions.
    """

    def __init__(self, node_count):
        self.node_count = node_count
        self.model = PolicyNet(input_dim=4, output_dim=node_count)
        self.optimizer = optim.Adam(self.model.parameters(), lr=1e-3)

        self.memory = []

    def select(self, state):
        logits = self.model(torch.tensor(state).float())
        probs = torch.softmax(logits, dim=-1)

        action = torch.multinomial(probs, 1).item()
        return action

    def store(self, transition):
        self.memory.append(transition)

    def train_step(self):
        if len(self.memory) < 8:
            return

        batch = self.memory[-32:]

        loss = 0
        for state, action, reward in batch:
            logits = self.model(torch.tensor(state).float())
            probs = torch.softmax(logits, dim=-1)

            log_prob = torch.log(probs[action] + 1e-8)
            loss -= log_prob * reward

        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        self.memory.clear()
