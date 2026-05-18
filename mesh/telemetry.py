from flask import Flask, jsonify
from mesh.discovery.node_discovery import NodeDiscovery
from mesh.router import MeshRouter

app = Flask(__name__)

discovery = NodeDiscovery()
router = MeshRouter()


@app.route("/metrics/routing")
def routing_metrics():
    nodes = discovery.get_nodes()

    return jsonify({
        "nodes": len(nodes),
        "active": len([n for n in nodes if n["status"] == "ready"]),
        "policy": "bandit-ema-v1"
    })


@app.route("/metrics/health")
def health():
    return jsonify({"status": "ok"})
