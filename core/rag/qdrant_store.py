import requests

QDRANT_URL = "http://localhost:6333"


class RAGQuery:
    def __init__(self, collection="hal_memory"):
        self.collection = collection

    def search(self, vector, limit=5):
        response = requests.post(
            f"{QDRANT_URL}/collections/{self.collection}/points/search",
            json={
                "vector": vector,
                "limit": limit
            }
        )

        return response.json()
