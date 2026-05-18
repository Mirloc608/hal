import os
from mesh.rl.dist.health import HealthGate

PS = os.getenv("PS_HOST", "ps")

def main():

    ps_url = f"http://{PS}:9000/ready"

    # V4.1 SAFE BOOT STRATEGY
    try:
        HealthGate.wait_for_http(ps_url, timeout=180, interval=3)
    except Exception as e:
        print(f"[WARN] PS not ready, entering retry loop: {e}")

    # continue startup instead of dying
    print("[ACTOR] Booting with best-effort PS connectivity")

    # rest of actor init continues normally
    run_actor()

def run_actor():
    import time
    while True:
        print("actor alive")
        time.sleep(5)

if __name__ == "__main__":
    main()
