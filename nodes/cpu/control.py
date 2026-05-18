from fastapi import FastAPI
import subprocess

app = FastAPI()

@app.post("/decide")
def decide(req: dict):

    # lightweight recovery hook
    if req.get("recover"):
        subprocess.Popen(["echo", "Recovery signal received"])

    return {
        "decision": "cpu_fallback_accepted",
        "status": "safe_mode"
    }
