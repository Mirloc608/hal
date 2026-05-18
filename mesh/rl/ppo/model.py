import torch
import torch.nn as nn
import torch.nn.functional as F


class PPOPolicyNet(nn.Module):
    """
    Lightweight routing policy network.
    Inputs: node + task features
    Outputs: probability distribution over nodes
    """

    def __init__(self, feature_dim=16, hidden=64):
        super().__init__()

        self.fc1 = nn.Linear(feature_dim, hidden)
        self.fc2 = nn.Linear(hidden, hidden)

        self.policy_head = nn.Linear(hidden, 1)  # per-node score
        self.value_head = nn.Linear(hidden, 1)

    def forward(self, x):
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))

        policy = self.policy_head(x)
        value = self.value_head(x)

        return policy, value
