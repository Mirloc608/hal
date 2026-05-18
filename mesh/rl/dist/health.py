import time
import requests

class HealthGate:

    @staticmethod
    def wait_for_http(url, timeout=120, interval=2):
        start = time.time()
        backoff = interval

        while True:
            try:
                r = requests.get(url, timeout=3)
                if r.status_code == 200:
                    return True
            except Exception:
                pass

            if time.time() - start > timeout:
                raise RuntimeError(f"Health check failed: {url}")

            time.sleep(backoff)

            # exponential backoff cap
            backoff = min(backoff * 1.5, 10)
