resource "aws_sqs_queue" "writes_dlq" {
  name                      = "${var.project}-writes-dlq"
  message_retention_seconds = 4 * 24 * 3600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "writes" {
  name                       = "${var.project}-writes"
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 20
  message_retention_seconds  = 24 * 3600
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.writes_dlq.arn
    maxReceiveCount     = 5
  })
}
