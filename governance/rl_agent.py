from fastapi import FastAPI
import random

app = FastAPI()

policy = {
    "fast_cache": 0.5,
    "balanced": 0.3,
    "deep_rag": 0.2
}


@app.post("/decide")
def decide(state: dict):

    actions = list(policy.keys())
    weights = list(policy.values())

    action = random.choices(actions, weights=weights)[0]

    # reward shaping placeholder
    latency = state.get("latency", 0)

    if latency < 100:
        policy[action] += 0.01
    else:
        policy[action] -= 0.01

    return {
        "action": action,
        "policy": policy
    }


@app.post("/feedback")
def feedback(data: dict):
    reward = data.get("reward", 0)
    action = data.get("action")

    if reward > 0:
        policy[action] += 0.01
    else:
        policy[action] -= 0.01

    return {"status": "updated"}
