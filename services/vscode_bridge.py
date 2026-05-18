from flask import Flask, request, jsonify

app = Flask(__name__)

CONNECTED_CLIENTS = []


@app.route("/event", methods=["POST"])
def event():
    data = request.json
    return jsonify({"status": "received", "event": data})


@app.route("/push", methods=["POST"])
def push():
    msg = request.json.get("message")
    return jsonify({"broadcast": msg})


@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "vscode_bridge"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9200)
