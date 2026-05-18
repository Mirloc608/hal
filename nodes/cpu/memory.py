from fastapi import FastAPI

app = FastAPI()

MEMORY = []

@app.post("/store")
def store(req: dict):
    MEMORY.append(req["data"])
    return {"stored": True, "size": len(MEMORY)}

@app.post("/retrieve")
def retrieve(req: dict):
    query = req.get("query", "")
    return {
        "results": [m for m in MEMORY if query in str(m)]
    }
