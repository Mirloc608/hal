"""Deterministic replay runner."""

def replay(events, fn):
    return [fn(e) for e in events]
