from fastapi import FastAPI
from hal.config.constitution import HAL_PERSONALITY

app = FastAPI()

@app.post("/llm")
def generate(req: dict):

    prompt = req.get("input", "")

    # simulate occasional instability awareness
    if "fail" in prompt:
        raise Exception("Simulated GPU stress failure")

    return {
        "response": f"[GPU ACTIVE]\n{prompt}",
        "personality": HAL_PERSONALITY
    }
