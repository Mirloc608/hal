import os
import time


class RuntimeConfig:
    """
    V4.1 Correctness Layer Runtime Config

    Adds:
    - policy versioning (PS-authoritative)
    - rollout identity tracking
    - Swarm-safe service discovery
    """

    # -------------------------
    # Service discovery
    # -------------------------

    @staticmethod
    def ps_host():
        return os.getenv("PS_HOST", "hal_ps")

    @staticmethod
    def ps_port():
        return int(os.getenv("PS_PORT", "9000"))

    @staticmethod
    def ps_url():
        return f"http://{RuntimeConfig.ps_host()}:{RuntimeConfig.ps_port()}"

    @staticmethod
    def redis_host():
        return os.getenv("REDIS_HOST", "redis")

    @staticmethod
    def redis_port():
        return int(os.getenv("REDIS_PORT", "6379"))

    @staticmethod
    def redis_url():
        return f"redis://{RuntimeConfig.redis_host()}:{RuntimeConfig.redis_port()}"

    # -------------------------
    # Identity
    # -------------------------

    @staticmethod
    def actor_id():
        return os.getenv("ACTOR_ID", str(int(time.time())))

    @staticmethod
    def role():
        return os.getenv("HAL_ROLE", "unknown")

    # -------------------------
    # PPO correctness layer
    # -------------------------

    @staticmethod
    def policy_version():
        """
        MUST match PS state.
        Used to prevent stale rollout contamination.
        """
        return int(os.getenv("POLICY_VERSION", "0"))

    @staticmethod
    def rollout_id():
        """
        Unique trajectory grouping ID per actor session.
        """
        return f"{RuntimeConfig.actor_id()}-{int(time.time() * 1000)}"

    @staticmethod
    def retry_backoff():
        return int(os.getenv("RETRY_BACKOFF", "3"))

    @staticmethod
    def swarm_boot_grace():
        return int(os.getenv("SWARM_BOOT_GRACE", "15"))
