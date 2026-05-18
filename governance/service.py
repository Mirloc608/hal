from fastapi import FastAPI

app = FastAPI()

state = {
    "latency_drift": 0,
    "error_rate": 0
}


@app.post("/analyze")
def analyze(metrics: dict):

    latency = metrics.get("latency", 0)
    error = metrics.get("error", 0)

    anomaly = False

    if latency > 400:
        state["latency_drift"] += 1
        anomaly = True

    if error > 0:
        state["error_rate"] += 1
        anomaly = True

    return {
        "anomaly": anomaly,
        "state": state
    }
