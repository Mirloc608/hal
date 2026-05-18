import os
import sys


REQUIRED_PATHS = [
    "/opt/hal/gateway/main.py",
    "/opt/hal/core/router/llm_router.py",
    "/opt/hal/core/mcp/mcp_server.py",
    "/opt/hal/core/rag/ingest.py",
]


def validate():
    print("HAL VALIDATION START")

    ok = True

    for path in REQUIRED_PATHS:
        if not os.path.exists(path):
            print(f"[FAIL] Missing: {path}")
            ok = False
        else:
            print(f"[OK] {path}")

    if not ok:
        print("HAL VALIDATION FAILED")
        sys.exit(1)

    print("HAL VALIDATION PASSED")


if __name__ == "__main__":
    validate()
