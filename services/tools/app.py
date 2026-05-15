import uuid
import time
from typing import Any, Dict, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.responses import PlainTextResponse

from prometheus_client import Counter, Histogram, generate_latest

from .runtime import registry, init_registry


# ---------------------------------------------------------
# Metrics
# ---------------------------------------------------------
TOOLS_REQUESTS = Counter(
    "hal_tools_requests_total",
    "Total number of tool execution requests",
    ["tool"]
)

TOOLS_ERRORS = Counter(
    "hal_tools_errors_total",
    "Total number of tool execution errors",
    ["tool"]
)

TOOLS_LATENCY = Histogram(
    "hal_tools_latency_seconds",
    "Latency of tool execution",
    ["tool"]
)


# ---------------------------------------------------------
# FastAPI App
# ---------------------------------------------------------
app = FastAPI(
    title="HAL Tools Service",
    version="3.0.0",
    description="HAL v2 Tool Execution Runtime"
)


# ---------------------------------------------------------
# Models
# ---------------------------------------------------------
class ToolRequest(BaseModel):
    tool: str
    args: Dict[str, Any] = {}
    trace_id: Optional[str] = None


class ToolResponse(BaseModel):
    ok: bool
    tool: Optional[str] = None
    trace_id: str
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None


# ---------------------------------------------------------
# Startup
# ---------------------------------------------------------
@app.on_event("startup")
async def startup_event() -> None:
    init_registry()


# ---------------------------------------------------------
# Health
# ---------------------------------------------------------
@app.get("/health")
async def health() -> Dict[str, Any]:
    return {
        "status": "ok",
        "service": "hal-tools",
        "version": "3.0.0"
    }


# ---------------------------------------------------------
# Metrics
# ---------------------------------------------------------
@app.get("/metrics")
def metrics():
    return PlainTextResponse(generate_latest(), media_type="text/plain")


# ---------------------------------------------------------
# Tool Execution Endpoint
# ---------------------------------------------------------
@app.post("/v1/tools/execute", response_model=ToolResponse)
async def execute_tool(req: ToolRequest) -> ToolResponse:
    trace_id = req.trace_id or f"tools-{uuid.uuid4()}"
    tool_name = req.tool

    tool_def = registry.get_tool(tool_name)
    if not tool_def:
        raise HTTPException(
            status_code=404,
            detail=f"Unknown tool: {tool_name}"
        )

    backend = tool_def.get("backend")
    handler = None

    try:
        handler = registry.get_handler(backend)
    except KeyError:
        raise HTTPException(
            status_code=500,
            detail=f"No handler registered for backend '{backend}'"
        )

    TOOLS_REQUESTS.labels(tool=tool_name).inc()
    start = time.time()

    try:
        result = await handler(req.args or {}, trace_id)
        ok = bool(result.get("ok", True))
        error = result.get("error")

        if not ok:
            TOOLS_ERRORS.labels(tool=tool_name).inc()

        return ToolResponse(
            ok=ok,
            tool=tool_name,
            trace_id=trace_id,
            result=result if ok else None,
            error=error,
        )

    except Exception as e:
        TOOLS_ERRORS.labels(tool=tool_name).inc()
        return ToolResponse(
            ok=False,
            tool=tool_name,
            trace_id=trace_id,
            error=str(e),
        )

    finally:
        TOOLS_LATENCY.labels(tool=tool_name).observe(time.time() - start)

try:
    # Ensure registry is populated for tests and import-time usage
    init_registry()
except Exception:
    # swallow errors during import to avoid breaking unrelated imports
    pass
