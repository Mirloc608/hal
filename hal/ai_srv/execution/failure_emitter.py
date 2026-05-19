"""Failure event emitter."""

def emit_failure(callback, payload):
    return callback(payload)
