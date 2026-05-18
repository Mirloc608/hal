from flask import Flask, jsonify
import os
import time

app = Flask(__name__)

START_TIME = time.time()

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "role": "parameter_server",
        "uptime": time.time() - START_TIME
    })

@app.route("/ready", methods=["GET"])
def ready():
    # simple readiness gate for swarm
    return jsonify({
        "ready": True
    })

@app.route("/", methods=["GET"])
def root():
    return "HAL PS ONLINE"

if __name__ == "__main__":
    port = int(os.getenv("PS_PORT", "9000"))
    app.run(host="0.0.0.0", port=port)

EXPERIENCE_BUFFER = []

@app.route("/experience", methods=["POST"])
def add_experience():
    from flask import request
    data = request.json
    EXPERIENCE_BUFFER.append(data)
    return {"status": "stored", "size": len(EXPERIENCE_BUFFER)}

@app.route("/batch", methods=["GET"])
def get_batch():
    return {"data": EXPERIENCE_BUFFER[-10:]}
