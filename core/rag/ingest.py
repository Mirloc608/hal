import requests
import hashlib

QDRANT_URL = "http://localhost:6333"


class RAGIngestor:
    def __init__(self, collection="hal_memory"):
        self.collection = collection

    def embed(self, text: str):
        # simple placeholder embedding via ollama (swap later if needed)
        r = requests.post(
            "http://localhost:11434/api/embeddings",
            json={"model": "llama3", "prompt": text}
        )
        return r.json().get("embedding", [])

    def store(self, text: str, metadata: dict = None):
        vector = self.embed(text)

        point = {
            "id": int(hashlib.md5(text.encode()).hexdigest(), 16) % (10**12),
            "vector": vector,
            "payload": metadata or {"text": text}
        }

        requests.put(
            f"{QDRANT_URL}/collections/{self.collection}/points",
            json={"points": [point]}
        )

        return {"status": "stored"}
