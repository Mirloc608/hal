from flask import Flask, request, jsonify
import importlib

app = Flask(__name__)

TOOLS = {}


def register_tool(name, module_path, function_name):
    module = importlib.import_module(module_path)
    TOOLS[name] = getattr(module, function_name)


@app.route("/run", methods=["POST"])
def run_tool():
    payload = request.json
    tool = payload.get("tool")
    args = payload.get("args", {})

    if tool not in TOOLS:
        return jsonify({"error": "unknown_tool"}), 404

    result = TOOLS[tool](**args)
    return jsonify({"result": result})


@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "mcp"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9100)
