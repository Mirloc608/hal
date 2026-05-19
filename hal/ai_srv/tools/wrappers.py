"""Tool wrapper helpers."""

def with_metrics(tool, metric_cb):
    def _wrapped(**kwargs):
        result = tool.run(**kwargs)
        metric_cb(tool.name)
        return result
    return _wrapped
