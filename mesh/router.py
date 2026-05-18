from mesh.rl.router_policy import RLRouterPolicy
from mesh.rl.ppo_worker import PPOWorker
from mesh.rl.ppo_obs import build_obs

worker = PPOWorker(obs_dim=9, action_dim=3)

def route_request(node_state, mesh_state, nodes):
    worker.sync()

    obs = build_obs(node_state, mesh_state)

    action, _, _ = worker.act(obs)

    idx = action % len(nodes)

    return nodes[idx], obs
