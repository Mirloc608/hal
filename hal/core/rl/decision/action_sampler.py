"""Action sampling utilities."""

import torch

def sample_action(logits):
    probs = torch.softmax(logits, dim=-1)
    dist = torch.distributions.Categorical(probs=probs)
    action = dist.sample()
    return action, dist.log_prob(action)
