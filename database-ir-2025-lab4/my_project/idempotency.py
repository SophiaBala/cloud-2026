import hashlib
import json
import logging
from functools import wraps

import redis
from flask import Response, jsonify, make_response, request

from my_project.redis_client import get_client

log = logging.getLogger(__name__)

TTL = 24 * 3600
LOCK_TTL = 60
HEADER = "Idempotency-Key"


def _fingerprint():
    body = request.get_data() or b""
    return hashlib.sha256(request.method.encode() + request.path.encode() + body).hexdigest()


def _replay(stored):
    resp = Response(stored["body"], status=stored["status"], mimetype="application/json")
    if stored.get("location"):
        resp.headers["Location"] = stored["location"]
    resp.headers["Idempotent-Replayed"] = "true"
    return resp


def idempotent(view):
    @wraps(view)
    def wrapper(*args, **kwargs):
        key = request.headers.get(HEADER)
        if not key:
            return view(*args, **kwargs)
        if len(key) > 255:
            return jsonify({"error": f"{HEADER} is too long"}), 400

        r = get_client()
        if r is None:
            return view(*args, **kwargs)

        rkey = f"idem:{request.path}:{key}"
        fp = _fingerprint()
        try:
            acquired = r.set(rkey, json.dumps({"state": "in_progress", "fp": fp}), nx=True, ex=LOCK_TTL)
            if not acquired:
                raw = r.get(rkey)
                stored = json.loads(raw) if raw else None
                if stored is None:
                    return jsonify({"error": "Request with this key is being processed"}), 409
                if stored["fp"] != fp:
                    return jsonify({"error": f"{HEADER} was already used with a different request"}), 422
                if stored["state"] == "in_progress":
                    resp = jsonify({"error": "Request with this key is being processed"})
                    resp.status_code = 409
                    resp.headers["Retry-After"] = "1"
                    return resp
                return _replay(stored)
        except redis.RedisError as e:
            log.warning("idempotency store unavailable: %s", e)
            return view(*args, **kwargs)

        try:
            resp = make_response(view(*args, **kwargs))
        except Exception:
            r.delete(rkey)
            raise

        if resp.status_code >= 500:
            r.delete(rkey)
        else:
            r.set(rkey, json.dumps({
                "state": "done",
                "fp": fp,
                "status": resp.status_code,
                "body": resp.get_data(as_text=True),
                "location": resp.headers.get("Location"),
            }), ex=TTL)
        return resp

    return wrapper
