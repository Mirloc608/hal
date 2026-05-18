#!/usr/bin/env python3

import subprocess
import json
import hashlib
from datetime import datetime
from pathlib import Path

PROD_STACK_DIR = "/srv/hal"
DEV_DIR = "/opt/hal"
REGISTRY = "192.168.1.250:5000"
STACK_NAME = "hal"

def run(cmd):
    print(f"[exec] {cmd}")
    return subprocess.check_call(cmd, shell=True)

def git_commit_hash():
    return subprocess.check_output(
        ["git", "-C", DEV_DIR, "rev-parse", "HEAD"]
    ).decode().strip()

def build_images(tag):
    services = [
        "hal-ps",
        "hal-ppo-actor",
        "hal-ppo-learner",
        "hal-mesh",
        "hal-gateway",
        "hal-rag",
        "hal-gpu"
    ]

    for svc in services:
        print(f"[build] {svc}")
        run(f"docker build -t {REGISTRY}/{svc}:{tag} {DEV_DIR}")

        run(f"docker push {REGISTRY}/{svc}:{tag}")

def write_release_manifest(tag, commit):
    manifest = {
        "tag": tag,
        "commit": commit,
        "timestamp": datetime.utcnow().isoformat(),
    }

    path = Path(PROD_STACK_DIR) / "state" / "release.json"
    path.parent.mkdir(parents=True, exist_ok=True)

    path.write_text(json.dumps(manifest, indent=2))
    print(f"[manifest] written to {path}")

def deploy_stack(tag):
    compose = f"{PROD_STACK_DIR}/docker-compose.yml"

    run(f"docker stack rm {STACK_NAME}")
    run("sleep 10")
    run(f"docker stack deploy -c {compose} {STACK_NAME}")

def main():
    commit = git_commit_hash()
    tag = hashlib.sha256(commit.encode()).hexdigest()[:12]

    print(f"[HAL] Deploying version {tag} from {commit}")

    build_images(tag)
    write_release_manifest(tag, commit)
    deploy_stack(tag)

    print("[HAL] Upgrade complete")

if __name__ == "__main__":
    main()
