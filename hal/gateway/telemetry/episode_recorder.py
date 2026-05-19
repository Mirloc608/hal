"""Episode recorder API."""

def record_episode(store: list, episode: dict):
    store.append(episode)
    return store
