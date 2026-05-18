from fastapi import APIRouter
from mesh.router import get_routing_weights
from mesh.discovery.node_discovery import get_swarm_nodes

router = APIRouter()


@router.get("/metrics/routing")
def routing_metrics():
    return {
        "rl_weights": get_routing_weights(),
        "swarm_nodes": get_swarm_nodes(),
        "type": "swarm_rl_heatmap"
    }
