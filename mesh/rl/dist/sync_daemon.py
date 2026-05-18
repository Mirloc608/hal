import redis
import pickle
import time

class SyncDaemon:
    def __init__(self):
        self.redis = redis.Redis(host="redis", port=6379, decode_responses=False)
        self.param_key = "policy:weights"
        self.version_key = "policy:version"

        self.local_version = -1
        self.weights = None

    def pull_latest(self):
        version = self.redis.get(self.version_key)
        if version is None:
            return

        version = int(version)

        if version != self.local_version:
            self.weights = pickle.loads(self.redis.get(self.param_key))
            self.local_version = version
            return True

        return False

    def run(self):
        while True:
            updated = self.pull_latest()

            if updated:
                print(f"[SYNC] Updated to v{self.local_version}")

            time.sleep(0.1)


if __name__ == "__main__":
    SyncDaemon().run()
