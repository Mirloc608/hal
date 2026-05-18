import docker
import os
import socket
from typing import Dict, List


class NodeDiscovery:
    """
    Swarm-native node discovery.
    No static registry. Everything is derived from Docker Swarm state.
    """

    def __init__(self):
        self.client = docker.from_env()

    def get_nodes(self) -> List[Dict]:
        nodes = self.client.nodes.list()
        result = []

        for n in nodes:
            info = n.attrs

            result.append({
                "id": info["ID"],
                "hostname": info["Description"]["Hostname"],
                "status": info["Status"]["State"],
                "availability": info["Spec"]["Availability"],
                "labels": info["Spec"].get("Labels", {}),
                "addr": info["Status"]["Addr"],
            })

        return result

    def get_active_nodes(self) -> List[Dict]:
        return [n for n in self.get_nodes() if n["status"] == "ready"]
