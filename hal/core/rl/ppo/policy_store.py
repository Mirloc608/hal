"""Policy persistence helpers for PPO."""

from pathlib import Path
import torch


def save_policy(model, path: str) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), path)


def load_policy(model, path: str):
    model.load_state_dict(torch.load(path, map_location="cpu"))
    return model
