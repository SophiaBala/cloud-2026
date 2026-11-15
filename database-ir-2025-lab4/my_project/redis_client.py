import os

import redis

_client = None


def get_client():
    global _client
    if _client is None and os.environ.get("REDIS_URL"):
        _client = redis.Redis.from_url(
            os.environ["REDIS_URL"],
            socket_timeout=0.5,
            socket_connect_timeout=0.5,
            health_check_interval=30,
        )
    return _client
