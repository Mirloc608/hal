from fastapi import FastAPI
import copy

app = FastAPI()

graph = {
    "gateway": ["optimizer", "rag", "llm"],
    "rag": ["vector_db"],
    "governance": ["optimizer"]
}


def validate(g):
    return "llm" in str(g)


@app.post("/apply")
def apply(change: dict):

    global graph

    new_graph = copy.deepcopy(graph)

    for k, v in change.items():
        new_graph[k] = v

    if not validate(new_graph):
        return {"status": "rejected"}

    graph = new_graph

    return {
        "status": "applied",
        "graph": graph
    }
