import json
import os
import time
import uuid

import pytest
import requests

BASE_URL = os.environ.get("BASE_URL", "http://localhost:8000").rstrip("/")
SQS_ENDPOINT_URL = os.environ.get("SQS_ENDPOINT_URL", "http://localhost:9324")
QUEUE_URL = os.environ.get("QUEUE_URL", "http://localhost:9324/000000000000/shop-writes")


def inserts():
    return requests.get(f"{BASE_URL}/stats", timeout=5).json()["db"]["Com_insert"]


def new_shop():
    return {"address": "Idempotency st. 1", "phone": f"+{uuid.uuid4().int % 10**12}", "city": "Lviv"}


def wait_job(job_id, timeout=30):
    deadline = time.time() + timeout
    while time.time() < deadline:
        job = requests.get(f"{BASE_URL}/jobs/{job_id}", timeout=5).json()
        if job["status"] in ("done", "failed"):
            return job
        time.sleep(0.5)
    pytest.fail(f"job {job_id} not finished in {timeout}s")


def test_same_key_creates_one_record_and_returns_same_response():
    key = str(uuid.uuid4())
    body = new_shop()
    before = inserts()

    first = requests.post(f"{BASE_URL}/shop", json=body, headers={"Idempotency-Key": key}, timeout=5)
    second = requests.post(f"{BASE_URL}/shop", json=body, headers={"Idempotency-Key": key}, timeout=5)

    assert first.status_code == 201
    assert second.status_code == first.status_code
    assert second.json() == first.json()
    assert second.headers.get("Idempotent-Replayed") == "true"
    assert inserts() - before == 1


def test_without_key_second_request_is_executed_again():
    body = new_shop()
    first = requests.post(f"{BASE_URL}/shop", json=body, timeout=5)
    second = requests.post(f"{BASE_URL}/shop", json=body, timeout=5)

    assert first.status_code == 201
    assert second.status_code != 201


def test_same_key_with_different_body_is_rejected():
    key = str(uuid.uuid4())
    assert requests.post(f"{BASE_URL}/shop", json=new_shop(), headers={"Idempotency-Key": key}, timeout=5).status_code == 201
    other = requests.post(f"{BASE_URL}/shop", json=new_shop(), headers={"Idempotency-Key": key}, timeout=5)
    assert other.status_code == 422


def test_async_same_key_enqueues_once():
    key = str(uuid.uuid4())
    body = new_shop()
    before = inserts()

    first = requests.post(f"{BASE_URL}/shop/async", json=body, headers={"Idempotency-Key": key}, timeout=5)
    second = requests.post(f"{BASE_URL}/shop/async", json=body, headers={"Idempotency-Key": key}, timeout=5)

    assert first.status_code == 202
    assert second.status_code == 202
    assert second.json() == first.json()

    job = wait_job(first.json()["job_id"])
    assert job["status"] == "done"
    assert job["result"]["phone"] == body["phone"]
    assert inserts() - before == 2


def test_worker_ignores_redelivered_message():
    boto3 = pytest.importorskip("boto3")
    if "localhost" not in SQS_ENDPOINT_URL and "127.0.0.1" not in SQS_ENDPOINT_URL:
        pytest.skip("needs direct access to the local queue")
    sqs = boto3.client("sqs", region_name="eu-central-1", endpoint_url=SQS_ENDPOINT_URL,
                       aws_access_key_id="local", aws_secret_access_key="local")

    created = requests.post(f"{BASE_URL}/shop/async", json=new_shop(), timeout=5).json()
    job = wait_job(created["job_id"])
    assert job["status"] == "done"
    original_shop_id = job["shop_id"]
    before = inserts()

    sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(
        {"job_id": created["job_id"], "op": "create_shop", "data": new_shop()}))
    deadline = time.time() + 30
    while time.time() < deadline:
        job = requests.get(f"{BASE_URL}/jobs/{created['job_id']}", timeout=5).json()
        if job.get("duplicate_delivery"):
            break
        time.sleep(0.5)

    assert job.get("duplicate_delivery") is True
    assert job["shop_id"] == original_shop_id
    assert inserts() - before == 0
    
