"""Failure tracking helpers."""

def track_failure(store: list, failure: dict):
    store.append(failure)
    return store
