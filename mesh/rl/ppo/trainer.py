import torch

def compute_ppo_loss(policy, batch):
    states, actions, old_log_probs, rewards, values = batch

    new_log_probs = policy.log_prob(states, actions)
    ratio = torch.exp(new_log_probs - old_log_probs)

    advantages = rewards - values

    clip_eps = 0.2

    clipped = torch.clamp(ratio, 1 - clip_eps, 1 + clip_eps) * advantages
    unclipped = ratio * advantages

    policy_loss = -torch.min(clipped, unclipped).mean()

    value_loss = (policy.value(states) - rewards).pow(2).mean()

    entropy = policy.entropy(states).mean()

    loss = policy_loss + 0.5 * value_loss - 0.01 * entropy

    loss.backward()

    return loss.item(), policy.parameters()
