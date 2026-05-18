from flask import Flask, request, jsonify
from core.router.llm_router import LLMRouter

app = Flask(__name__)
router = LLMRouter()


@app.route("/chat", methods=["POST"])
def chat():
    data = request.json
    prompt = data.get("prompt", "")

    result = router.generate(prompt, task_type="small_task")
    return jsonify(result)


@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "gateway"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=7200)
