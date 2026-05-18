from fastapi import FastAPI
from mesh.router import route_request

app = FastAPI()

def get_mesh_state():
    return {
        "avg_latency": 0.12,
        "error_rate": 0.01,
        "queue_depth": 3,
        "active_nodes": 3,
        "failed_nodes": 0
    }

def get_node_state():
    return {
        "cpu": 0.4,
        "gpu": 0.2,
        "mem": 0.6
    }

@app.post("/chat")
def chat(req: dict):

    nodes = ["cpu", "gpu", "rag"]

    node, obs = route_request(
        get_node_state(),
        get_mesh_state(),
        nodes
    )

    return {
        "node": node,
        "obs": obs,
        "status": "rl_routed"
    }
