import time
from mesh.rl.ppo_worker import PPOWorker
from mesh.rl.ps.client import submit_to_ps

worker = PPOWorker(9, 3)

while True:
    worker.sync()

    obs = get_router_state()
    latency, success, load = get_metrics()

    worker.step(obs, latency, success, load)

    grads = worker.compute_grads()

    if grads:
        submit_to_ps(grads)

    time.sleep(0.02)
