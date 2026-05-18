import torch
from .ppo_config import PPOConfig

class PPOTrainer:
    def __init__(self, agent):
        self.agent = agent

    def compute_advantages(self, rewards, values, dones):
        adv = []
        gae = 0

        for t in reversed(range(len(rewards))):
            delta = rewards[t] + PPOConfig.GAMMA * (0 if dones[t] else values[t]) - values[t]
            gae = delta + PPOConfig.GAMMA * PPOConfig.GAE_LAMBDA * (0 if dones[t] else gae)
            adv.insert(0, gae)

        return adv

    def update(self, buffer):
        obs = torch.tensor(buffer.obs, dtype=torch.float32)
        actions = torch.tensor(buffer.actions)
        old_logprobs = torch.tensor(buffer.logprobs)

        rewards = buffer.rewards
        values = buffer.values
        dones = buffer.dones

        advantages = torch.tensor(self.compute_advantages(rewards, values, dones))
        returns = advantages + torch.tensor(values)

        for _ in range(4):  # PPO epochs
            logprob, value, entropy = self.agent.evaluate(obs, actions)

            ratio = torch.exp(logprob - old_logprobs)
            clipped = torch.clamp(ratio, 1 - PPOConfig.CLIP_EPS, 1 + PPOConfig.CLIP_EPS)

            policy_loss = -torch.min(ratio * advantages, clipped * advantages).mean()
            value_loss = ((returns - value) ** 2).mean()
            entropy_loss = entropy.mean()

            loss = policy_loss + PPOConfig.VALUE_COEF * value_loss - PPOConfig.ENTROPY_COEF * entropy_loss

            self.agent.opt.zero_grad()
            loss.backward()
            self.agent.opt.step()
