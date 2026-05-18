from fastapi import FastAPI
import random

app = FastAPI()

weights = [0.5, 0.3, 0.2]  # fast, balanced, deep


@app.post("/decide")
def decide(state: dict):

    choice = random.choices(
        ["fast_cache", "balanced", "deep_rag"],
        weights=weights
    )[0]

    return {"action": choice}
