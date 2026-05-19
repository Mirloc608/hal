"""Generalized advantage estimation helpers."""

import torch


def compute_gae(rewards, values, dones, gamma=0.99, lam=0.95):
    adv = torch.zeros_like(rewards)
    last = 0.0
    for t in reversed(range(len(rewards))):
        mask = 1.0 - dones[t]
        delta = rewards[t] + gamma * values[t + 1] * mask - values[t]
        last = delta + gamma * lam * mask * last
        adv[t] = last
    return adv
