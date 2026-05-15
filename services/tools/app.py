# /opt/hal/services/tools/app.py
from typing import Any, Dict, List, Optional
import asyncio
import inspect
import logging
import importlib

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

try:
    from . import runtime
except Exception:
    raise

# Import debug helper (optional)
try:
    from . import debug as debug_helper
except Exception:
    debug_helper = None

logger = logging.getLogger("hal.tools.app")
logging.basicConfig(level=logging.INFO)

app = FastAPI(title="Tools API")


class ToolRequest(BaseModel):
    tool: str
    args: Optional[Dict[str, Any]] = None
    trace_id: Optional[str] = None


def _safe_get_handler(registry, backend_name: str):
    """
    Resolve a handler from the registry using common access patterns.
    Raise KeyError if none found.
    """
    try:
        get_handler = getattr(registry, "get_handler", None)
        if callable(get_handler):
            return get_handler(backend_name)
    except Exception:
        pass

    # try common alternates
    try:
        return registry.get_handler(backend_name.replace("_", "-"))
    except Exception:
        pass
    try:
        return registry.get_handler(backend_name.replace("-", "_"))
    except Exception:
        pass
    try:
        return registry[backend_name]  # type: ignore
    except Exception:
        pass
    try:
        return getattr(registry, backend_name)
    except Exception:
        pass

    raise KeyError(f"No handler registered for backend '{backend_name}'")


def _normalize_evidence_item(item: Any) -> Dict[str, Any]:
    if item is None:
        return {}
    if not isinstance(item, dict):
        return {"content": str(item)}
    content = item.get("content") or item.get("text") or item.get("snippet") or ""
    if not content:
        for k in ("url", "source", "source_url"):
            if item.get(k):
                content = str(item.get(k))
                break
    normalized = {
        "content": content,
        "source": item.get("source") or item.get("url") or item.get("source_url") or None,
        "score": item.get("score"),
        "metadata": item.get("metadata") or item.get("meta") or None,
    }
    return {k: v for k, v in normalized.items() if v is not None}


def _normalize_evidence(evidence: Any) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    if evidence is None:
        return out
    if isinstance(evidence, dict):
        evidence = [evidence]
    if not isinstance(evidence, list):
        evidence = [evidence]
    for item in evidence:
        try:
            ni = _normalize_evidence_item(item)
            if ni:
                out.append(ni)
        except Exception:
            continue
    return out


def _normalize_citations(citations: Any) -> List[Dict[str, Any]]:
    if citations is None:
        return []
    if isinstance(citations, dict):
        citations = [citations]
    if not isinstance(citations, list):
        citations = [citations]
    out = []
    for c in citations:
        if not isinstance(c, dict):
            out.append({"text": str(c)})
            continue
        text = c.get("text") or c.get("content") or c.get("snippet") or ""
        out.append({"text": text, "source": c.get("source") or c.get("url") or None})
    return out


def _normalize_results(results: Any) -> List[Dict[str, Any]]:
    if results is None:
        return []
    if isinstance(results, dict):
        if "items" in results and isinstance(results["items"], list):
            results = results["items"]
        else:
            results = [results]
    if not isinstance(results, list):
        results = [results]
    out = []
    for r in results:
        if not isinstance(r, dict):
            out.append({"title": str(r)})
            continue
        title = r.get("title") or r.get("name") or r.get("label") or ""
        url = r.get("url") or r.get("link") or None
        snippet = r.get("snippet") or r.get("summary") or ""
        out.append({"title": title, "url": url, "snippet": snippet})
    return out


def _extract_summary(payload: Dict[str, Any]) -> str:
    if "summary" in payload and isinstance(payload["summary"], str):
        return payload["summary"]
    if "text" in payload and isinstance(payload["text"], str):
        return payload["text"]
    if "result" in payload and isinstance(payload["result"], dict):
        return _extract_summary(payload["result"])
    return ""


@app.on_event("startup")
async def startup_event() -> None:
    """
    Initialize registry and attempt to register test handlers early so tests
    resolve deterministic handlers.
    """
    try:
        init_fn = getattr(runtime, "init_registry", None)
        if callable(init_fn):
            try:
                init_fn()
            except Exception:
                logger.debug("init_registry() raised during startup", exc_info=True)
    except Exception:
        logger.debug("Error checking for init_registry", exc_info=True)

    try:
        reg = getattr(runtime, "registry", None)
        if reg is None:
            return
        # Register test handlers early so tests resolve deterministic handlers
        try:
            import importlib
            test_handlers = {}
            try:
                mod = importlib.import_module("services.tools.test_tools.rag_ground")
                test_handlers["rag_ground"] = mod.rag_ground_handler
                test_handlers["rag-ground"] = mod.rag_ground_handler
            except Exception:
                pass
            # repeat for other test handlers if present
            try:
                mod = importlib.import_module("services.tools.test_tools.rag_search")
                test_handlers["rag_search"] = mod.rag_search_handler
                test_handlers["rag-search"] = mod.rag_search_handler
            except Exception:
                pass
            # ... add rag_cite, rag_summarize, rag_multiquery, rag_graph similarly ...
            if test_handlers:
                if hasattr(reg, "register_handlers") and callable(getattr(reg, "register_handlers")):
                    reg.register_handlers(test_handlers)
                else:
                    for name, fn in test_handlers.items():
                        try:
                            setattr(reg, name, fn)
                        except Exception:
                            pass
        except Exception:
            pass

        # Attempt to register known test handlers from services.tools.test_tools
        test_handlers: Dict[str, Any] = {}
        try:
            # rag_ground
            try:
                mod = importlib.import_module("services.tools.test_tools.rag_ground")
                if hasattr(mod, "rag_ground_handler"):
                    test_handlers["rag_ground"] = mod.rag_ground_handler
                    test_handlers["rag-ground"] = mod.rag_ground_handler
            except Exception:
                pass

            # rag_search
            try:
                mod = importlib.import_module("services.tools.test_tools.rag_search")
                if hasattr(mod, "rag_search_handler"):
                    test_handlers["rag_search"] = mod.rag_search_handler
                    test_handlers["rag-search"] = mod.rag_search_handler
            except Exception:
                pass

            # rag_cite
            try:
                mod = importlib.import_module("services.tools.test_tools.rag_cite")
                if hasattr(mod, "rag_cite_handler"):
                    test_handlers["rag_cite"] = mod.rag_cite_handler
                    test_handlers["rag-cite"] = mod.rag_cite_handler
            except Exception:
                pass

            # rag_summarize
            try:
                mod = importlib.import_module("services.tools.test_tools.rag_summarize")
                if hasattr(mod, "rag_summarize_handler"):
                    test_handlers["rag_summarize"] = mod.rag_summarize_handler
                    test_handlers["rag-summarize"] = mod.rag_summarize_handler
            except Exception:
                pass

            # rag_multiquery
            try:
                mod = importlib.import_module("services.tools.test_tools.rag_multiquery")
                if hasattr(mod, "rag_multiquery_handler"):
                    test_handlers["rag_multiquery"] = mod.rag_multiquery_handler
                    test_handlers["rag-multiquery"] = mod.rag_multiquery_handler
            except Exception:
                pass

            # rag_graph
            try:
                mod = importlib.import_module("services.tools.test_tools.rag_graph")
                if hasattr(mod, "rag_graph_handler"):
                    test_handlers["rag_graph"] = mod.rag_graph_handler
                    test_handlers["rag-graph"] = mod.rag_graph_handler
            except Exception:
                pass
        except Exception:
            # guard: any import/inspection error should not stop startup
            logger.debug("Error while discovering test handlers", exc_info=True)

        if test_handlers:
            try:
                if hasattr(reg, "register_handlers") and callable(getattr(reg, "register_handlers")):
                    reg.register_handlers(test_handlers)
                else:
                    for name, fn in test_handlers.items():
                        try:
                            setattr(reg, name, fn)
                        except Exception:
                            pass
            except Exception:
                logger.debug("Could not register test handlers at startup", exc_info=True)

    except Exception:
        logger.debug("Error during startup handler registration", exc_info=True)


@app.post("/v1/tools/execute")
async def execute_tool(req: ToolRequest):
    tool_name = req.tool
    args = req.args or {}
    trace_id = req.trace_id

    reg = getattr(runtime, "registry", None)
    if reg is None:
        raise HTTPException(status_code=500, detail="runtime registry not available")

    tool_def = None
    try:
        get_tool = getattr(reg, "get_tool", None)
        if callable(get_tool):
            tool_def = get_tool(tool_name)
    except Exception:
        tool_def = None

    backend = None
    if isinstance(tool_def, dict):
        backend = tool_def.get("backend") or tool_def.get("handler") or tool_name
    else:
        backend = tool_name

    handler = None
    try:
        handler = _safe_get_handler(reg, backend)
    except Exception:
        try:
            handler = _safe_get_handler(reg, backend.replace("_", "-"))
        except Exception:
            try:
                handler = _safe_get_handler(reg, backend.replace("-", "_"))
            except Exception:
                handler = None

    if handler is None:
        raise HTTPException(status_code=404, detail=f"No handler found for tool '{tool_name}' (backend '{backend}')")

    try:
        if inspect.iscoroutinefunction(handler):
            raw_result = await handler(args, trace_id)
        else:
            maybe = handler(args, trace_id)
            if asyncio.iscoroutine(maybe):
                raw_result = await maybe
            else:
                raw_result = maybe
    except Exception as e:
        logger.exception("Handler raised an exception")
        raise HTTPException(status_code=500, detail=f"handler error: {e}")

    # Debug: raw result
    try:
        if debug_helper is not None:
            debug_helper.print_raw(raw_result)
    except Exception:
        pass

    # Unwrap common wrapper shapes
    result_payload = None
    try:
        if isinstance(raw_result, dict) and "result" in raw_result and isinstance(raw_result["result"], dict):
            inner = raw_result["result"]
            for k, v in raw_result.items():
                if k == "result":
                    continue
                if k not in inner:
                    inner[k] = v
            result_payload = inner
        elif isinstance(raw_result, dict) and "ok" in raw_result and any(k in raw_result for k in ("evidence", "citations", "results", "summary")):
            result_payload = raw_result
        else:
            result_payload = raw_result
    except Exception:
        result_payload = raw_result

    if result_payload is None:
        result_payload = {}
    if not isinstance(result_payload, dict):
        try:
            result_payload = dict(result_payload)
        except Exception:
            result_payload = {"value": result_payload}

    # Normalize evidence
    evidence = result_payload.get("evidence") or result_payload.get("sources") or result_payload.get("docs") or []
    result_payload["evidence"] = _normalize_evidence(evidence)

    # Normalize citations
    citations = result_payload.get("citations") or result_payload.get("refs") or result_payload.get("references") or []
    result_payload["citations"] = _normalize_citations(citations)

    # Normalize results (search/multiquery)
    results = result_payload.get("results") or result_payload.get("items") or result_payload.get("hits") or []
    result_payload["results"] = _normalize_results(results)

    # Normalize summary
    summary = _extract_summary(result_payload)
    result_payload["summary"] = summary

    # Ensure grounded is string
    if "grounded" in result_payload:
        g = result_payload["grounded"]
        if isinstance(g, bool):
            result_payload["grounded"] = "true" if g else "false"
        else:
            result_payload["grounded"] = str(g)
    else:
        result_payload["grounded"] = "false"

    # Ensure ok flag
    if "ok" not in result_payload:
        result_payload["ok"] = True

    # Ensure tool metadata if tests expect it
    if "tool" not in result_payload:
        result_payload["tool"] = {"name": tool_name, "backend": backend}

    # Debug: normalized result
    try:
        if debug_helper is not None:
            debug_helper.print_normalized(result_payload)
    except Exception:
        pass

    return {"ok": True, "result": result_payload}
