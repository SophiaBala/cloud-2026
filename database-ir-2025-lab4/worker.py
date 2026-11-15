import json
import logging
import os
import signal
import time

from sqlalchemy.exc import IntegrityError

from app import app
from my_project import db, jobs, queue
from my_project.auth.domain.processed_job import ProcessedJob
from my_project.auth.domain.shop import Shop

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("worker")

DELAY = int(os.environ.get("WORKER_DELAY_MS", "200")) / 1000
running = True


def stop(*_):
    global running
    running = False
    log.info("stop requested, finishing current batch")


def create_shop(job_id, data):
    done = db.session.get(ProcessedJob, job_id)
    if done:
        log.info("job %s already processed (shop %s), skipping", job_id, done.shop_id)
        return "done", {"shop_id": done.shop_id, "duplicate_delivery": True}

    time.sleep(DELAY)

    shop = Shop(address=data.get("address"), phone=data["phone"], city=data["city"])
    db.session.add(shop)
    try:
        db.session.flush()
        db.session.add(ProcessedJob(job_id=job_id, shop_id=shop.idshop))
        db.session.commit()
    except IntegrityError as e:
        db.session.rollback()
        done = db.session.get(ProcessedJob, job_id)
        if done:
            return "done", {"shop_id": done.shop_id, "duplicate_delivery": True}
        return "failed", {"error": str(e.orig)}
    return "done", {"shop_id": shop.idshop, "result": shop.to_dict()}


def handle(message):
    body = json.loads(message["Body"])
    job_id = body["job_id"]
    receive_count = int(message.get("Attributes", {}).get("ApproximateReceiveCount", "1"))
    jobs.save(job_id, "processing", attempt=receive_count)
    with app.app_context():
        try:
            status, fields = create_shop(job_id, body["data"])
        finally:
            db.session.remove()
    jobs.save(job_id, status, attempt=receive_count, **fields)
    log.info("job %s -> %s (attempt %s)", job_id, status, receive_count)


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    sqs = queue.client()
    log.info("worker started, queue=%s delay=%ss", queue.QUEUE_URL, DELAY)
    while running:
        resp = sqs.receive_message(
            QueueUrl=queue.QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20,
            AttributeNames=["ApproximateReceiveCount"],
        )
        for message in resp.get("Messages", []):
            try:
                handle(message)
            except Exception:
                log.exception("message %s failed, will be redelivered", message["MessageId"])
                continue
            sqs.delete_message(QueueUrl=queue.QUEUE_URL, ReceiptHandle=message["ReceiptHandle"])


if __name__ == "__main__":
    main()
