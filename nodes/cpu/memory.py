import json
import os
import sqlite3
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, HTTPException

try:
    import redis
except ImportError:  # pragma: no cover
    redis = None

app = FastAPI(title="HAL Memory Service")

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_DB = int(os.getenv("REDIS_DB", "0"))
REDIS_TTL_SECONDS = int(os.getenv("REDIS_TTL_SECONDS", "3600"))

IRIS_DB_PATH = os.getenv("IRIS_DB_PATH", "/opt/hal/runtime/memory/iris_memory.db")


class RedisImmediateMemory:
    def __init__(self) -> None:
        self._client = None
        if redis is not None:
            self._client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                db=REDIS_DB,
                decode_responses=True,
            )

    def available(self) -> bool:
        if self._client is None:
            return False
        try:
            self._client.ping()
            return True
        except Exception:
            return False

    def set(self, key: str, payload: dict[str, Any]) -> None:
        if self._client is None:
            return
        self._client.setex(f"hal:immediate:{key}", REDIS_TTL_SECONDS, json.dumps(payload))

    def get(self, key: str) -> dict[str, Any] | None:
        if self._client is None:
            return None
        raw = self._client.get(f"hal:immediate:{key}")
        return json.loads(raw) if raw else None


class IrisPermanentMemory:
    """Permanent memory store implemented with an IRIS-designated local DB path."""

    def __init__(self, db_path: str) -> None:
        self.db_path = db_path
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self.db_path)

    def _init_db(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS permanent_memory (
                    memory_key TEXT PRIMARY KEY,
                    payload TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )
                """
            )
            conn.commit()

    def upsert(self, key: str, payload: dict[str, Any]) -> None:
        created_at = datetime.now(timezone.utc).isoformat()
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO permanent_memory(memory_key, payload, created_at)
                VALUES(?, ?, ?)
                ON CONFLICT(memory_key) DO UPDATE SET
                    payload=excluded.payload,
                    created_at=excluded.created_at
                """,
                (key, json.dumps(payload), created_at),
            )
            conn.commit()

    def get(self, key: str) -> dict[str, Any] | None:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT payload FROM permanent_memory WHERE memory_key = ?",
                (key,),
            ).fetchone()
        return json.loads(row[0]) if row else None


immediate_store = RedisImmediateMemory()
permanent_store = IrisPermanentMemory(IRIS_DB_PATH)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "redis_available": immediate_store.available(),
        "iris_path": IRIS_DB_PATH,
    }


@app.post("/store")
def store(req: dict[str, Any]) -> dict[str, Any]:
    key = req.get("key")
    data = req.get("data")
    if not key:
        raise HTTPException(status_code=400, detail="key is required")
    if data is None:
        raise HTTPException(status_code=400, detail="data is required")

    payload = {"key": key, "data": data, "updated_at": datetime.now(timezone.utc).isoformat()}
    immediate_store.set(key, payload)
    permanent_store.upsert(key, payload)

    return {"stored": True, "key": key, "immediate": True, "permanent": True}


@app.post("/retrieve")
def retrieve(req: dict[str, Any]) -> dict[str, Any]:
    key = req.get("key")
    if not key:
        raise HTTPException(status_code=400, detail="key is required")

    immediate = immediate_store.get(key)
    if immediate is not None:
        return {"key": key, "source": "redis", "result": immediate}

    permanent = permanent_store.get(key)
    if permanent is not None:
        return {"key": key, "source": "iris", "result": permanent}

    return {"key": key, "source": "none", "result": None}
