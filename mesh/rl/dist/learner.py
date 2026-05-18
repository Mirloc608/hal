from mesh.rl.ppo.policy import PPOPolicy
from mesh.rl.ps.parameter_server import ParameterServerV3
from mesh.rl.ppo.trainer import compute_ppo_loss

ps = ParameterServerV3()
policy = PPOPolicy()

def train_step(batch):
    loss, grads = compute_ppo_loss(policy, batch)

    # CRITICAL: only send gradients, never sync weights peer-to-peer
    ps.submit_gradients(grads, worker_id="learner")

    return loss

def loop():
    while True:
        batch = get_batch_from_mesh()

        loss = train_step(batch)

        if ps.get_version() % 10 == 0:
            print(f"[PPO-v3] version={ps.get_version()} loss={loss}")

        time.sleep(0.05)

if __name__ == "__main__":
    loop()
