from mesh.rl.worker.ppo_worker import PPOWorker

rl_worker = PPOWorker(16, 8)

def route_request(obs, nodes):
    rl_worker.sync()

    action, _, _ = rl_worker.act(obs)

    idx = action % len(nodes)
    return nodes[idx]
