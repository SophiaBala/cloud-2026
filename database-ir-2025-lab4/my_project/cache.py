import json
import logging
import os

import redis

log = logging.getLogger(__name__)

ENABLED = os.environ.get("CACHE_ENABLED", "false").lower() in ("1", "true", "yes")
TTL = int(os.environ.get("CACHE_TTL", "45"))

_client = None
if ENABLED and os.environ.get("REDIS_URL"):
    _client = redis.Redis.from_url(
        os.environ["REDIS_URL"],
        socket_timeout=0.3,
        socket_connect_timeout=0.5,
        health_check_interval=30,
    )

def get_json(key):
    if _client is None:
        return None, "BYPASS"
    try:
        raw = _client.get(key)
    except redis.RedisError as e:
        log.warning("cache get failed: %s", e)
        return None, "ERROR"
    if raw is None:
        return None, "MISS"
    return json.loads(raw), "HIT"

def set_json(key, value):
    if _client is None:
        return
    try:
        _client.set(key, json.dumps(value), ex=TTL)
    except redis.RedisError as e:
        log.warning("cache set failed: %s", e)

def stats():
    info = {"enabled": ENABLED, "ttl": TTL}
    if _client is None:
        return info
    try:
        s = _client.info("stats")
        info.update(hits=s.get("keyspace_hits"), misses=s.get("keyspace_misses"))
    except redis.RedisError as e:
        info["error"] = str(e)
    return info
