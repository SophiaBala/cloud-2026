import json
import time

from my_project.redis_client import get_client

TTL = 24 * 3600


def _key(job_id):
    return f"job:{job_id}"


def save(job_id, status, **fields):
    job = {"job_id": job_id, "status": status, "updated_at": time.time(), **fields}
    get_client().set(_key(job_id), json.dumps(job), ex=TTL)
    return job


def get(job_id):
    raw = get_client().get(_key(job_id))
    return json.loads(raw) if raw else None
