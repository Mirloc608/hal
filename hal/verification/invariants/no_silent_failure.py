"""Invariant: failures must be explicit."""

def assert_no_silent_failure(result):
    if result is None:
        raise AssertionError("silent failure detected")
