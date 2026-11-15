import json
import os

import boto3

QUEUE_URL = os.environ.get("QUEUE_URL")

_client = None


def client():
    global _client
    if _client is None:
        _client = boto3.client(
            "sqs",
            region_name=os.environ.get("AWS_REGION", "eu-central-1"),
            endpoint_url=os.environ.get("SQS_ENDPOINT_URL") or None,
        )
    return _client


def enabled():
    return bool(QUEUE_URL)


def send(payload):
    return client().send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(payload))["MessageId"]
