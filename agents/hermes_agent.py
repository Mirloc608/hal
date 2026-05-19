import os
from typing import Any

import requests


HAL_MEMORY_SERVICE_URL = os.getenv("HAL_MEMORY_SERVICE_URL", "http://localhost:7200")


class HermesAgent:
    """Hermes sidecar agent for async support workloads on CPU nodes."""

    def __init__(self, memory_service_url: str = HAL_MEMORY_SERVICE_URL) -> None:
        self.memory_service_url = memory_service_url.rstrip("/")

    def remember(self, key: str, data: Any) -> dict[str, Any]:
        response = requests.post(
            f"{self.memory_service_url}/store",
            json={"key": key, "data": data},
            timeout=10,
        )
        response.raise_for_status()
        return response.json()

    def recall(self, key: str) -> dict[str, Any]:
        response = requests.post(
            f"{self.memory_service_url}/retrieve",
            json={"key": key},
            timeout=10,
        )
        response.raise_for_status()
        return response.json()


if __name__ == "__main__":
    agent = HermesAgent()
    print("Hermes Agent ready", {"memory_service": agent.memory_service_url})
