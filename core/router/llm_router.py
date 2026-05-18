import requests
import yaml

CONFIG_PATH = "/opt/hal/config/runtime.yaml"


class LLMRouter:
    def __init__(self):
        with open(CONFIG_PATH, "r") as f:
            self.config = yaml.safe_load(f)

        self.ollama_host = self.config["ollama"]["host"]
        self.routes = self.config["llm"]["router"]
        self.default = self.config["llm"]["default_model"]

    def select_model(self, task_type: str) -> str:
        return self.routes.get(task_type, self.default)

    def generate(self, prompt: str, task_type: str = "small_task"):
        model = self.select_model(task_type)

        response = requests.post(
            f"{self.ollama_host}/api/generate",
            json={
                "model": model,
                "prompt": prompt,
                "stream": False
            },
            timeout=120
        )

        return response.json()
