import os

class PPOConfig:
    CLIP_EPS = float(os.getenv("PPO_CLIP_EPS", 0.2))
    LR = float(os.getenv("PPO_LR", 3e-4))
    GAMMA = float(os.getenv("PPO_GAMMA", 0.99))
    GAE_LAMBDA = float(os.getenv("PPO_GAE_LAMBDA", 0.95))

    BATCH_SIZE = int(os.getenv("PPO_BATCH", 64))
    MINIBATCH_SIZE = int(os.getenv("PPO_MINIBATCH", 16))

    ENTROPY_COEF = float(os.getenv("PPO_ENTROPY", 0.01))
    VALUE_COEF = float(os.getenv("PPO_VALUE", 0.5))

    SYNC_STEPS = int(os.getenv("PPO_SYNC_STEPS", 10))
