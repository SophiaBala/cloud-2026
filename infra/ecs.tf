resource "null_resource" "initial_image" {
  triggers = {
    repo = aws_ecr_repository.app.repository_url
    tag  = var.image_tag
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.registry_id}.dkr.ecr.${var.region}.amazonaws.com
      docker build --platform linux/amd64 -t ${aws_ecr_repository.app.repository_url}:${var.image_tag} ../database-ir-2025-lab4/
      docker push ${aws_ecr_repository.app.repository_url}:${var.image_tag}
    EOT
  }
}

locals {
  app_env = [
    { name = "DB_HOST", value = aws_db_instance.mysql.address },
    { name = "DB_PORT", value = "3306" },
    { name = "DB_NAME", value = var.db_name },
    { name = "DB_USER", value = var.db_username },
    { name = "DB_PASSWORD", value = var.db_password },
    { name = "REDIS_URL", value = "rediss://${aws_elasticache_replication_group.cache.primary_endpoint_address}:6379/0" },
    { name = "QUEUE_URL", value = aws_sqs_queue.writes.url },
    { name = "AWS_REGION", value = var.region },
  ]
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "container_insights" {
  name              = "/aws/ecs/containerinsights/${var.project}-cluster/performance"
  retention_in_days = 1
}

resource "aws_ecs_cluster" "main" {
  name       = "${var.project}-cluster"
  depends_on = [aws_cloudwatch_log_group.container_insights]

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_exec" {
  name               = "${var.project}-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "task_exec" {
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.project
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_exec.arn
  task_role_arn            = aws_iam_role.api_task.arn

  container_definitions = jsonencode([{
    name         = "app"
    image        = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
    essential    = true
    portMappings = [{ containerPort = var.container_port }]

    environment = concat(local.app_env, [
      { name = "PORT", value = tostring(var.container_port) },
      { name = "CACHE_ENABLED", value = tostring(var.cache_enabled) },
      { name = "CACHE_TTL", value = tostring(var.cache_ttl_seconds) },
    ])

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "app"
      }
    }
  }])
}

resource "aws_ecs_service" "app" {
  name                              = "${var.project}-svc"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.app.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 180

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.http,
    null_resource.initial_image,
    aws_vpc_endpoint.interface,
    aws_vpc_endpoint.s3,
  ]

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}