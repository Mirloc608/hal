class GradientAggregator:
    """
    True PPO distributed sync layer.
    No HTTP polling. Only in-memory or queue-based sync.
    """

    def __init__(self):
        self.buffer = []
        self.version = 0

    def submit(self, grads, worker_id):
        self.buffer.append((worker_id, grads))

    def should_update(self):
        return len(self.buffer) >= self.expected_workers()

    def aggregate(self):
        # simple all-reduce mean (v3 baseline)
        summed = None
        for _, g in self.buffer:
            summed = g if summed is None else summed + g

        avg = summed / len(self.buffer)
        self.buffer.clear()

        self.version += 1
        return avg, self.version
