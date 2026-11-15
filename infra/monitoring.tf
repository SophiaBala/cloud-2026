locals {
  alert_email = coalesce(var.alert_email, var.budget_email)

  ecs_dims = { ClusterName = aws_ecs_cluster.main.name, ServiceName = aws_ecs_service.app.name }
  alb_dim  = aws_lb.main.arn_suffix
  tg_dim   = aws_lb_target_group.app.arn_suffix
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = local.alert_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project}-cpu-high"
  alarm_description   = "Average CPU of ${aws_ecs_service.app.name} above 70% for 2 minutes"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = local.ecs_dims
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 70
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Tasks: desired vs running"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["ECS/ContainerInsights", "DesiredTaskCount", "ClusterName", local.ecs_dims.ClusterName, "ServiceName", local.ecs_dims.ServiceName, { label = "Desired" }],
            [".", "RunningTaskCount", ".", ".", ".", ".", { label = "Running" }],
          ]
          yAxis = { left = { min = 0, max = var.autoscaling_max + 1 } }
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "CPU utilization, %"
          region  = var.region
          view    = "timeSeries"
          period  = 60
          metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", local.ecs_dims.ClusterName, "ServiceName", local.ecs_dims.ServiceName, { stat = "Average", label = "Average CPU" }]]
          yAxis   = { left = { min = 0, max = 100 } }
          annotations = {
            horizontal = [
              { label = "Scaling target", value = var.cpu_target },
              { label = "Alert threshold", value = 70, color = "#d62728" },
            ]
          }
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 8, height = 6
        properties = {
          title   = "Requests per minute"
          region  = var.region
          view    = "timeSeries"
          period  = 60
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_dim, { stat = "Sum", label = "Requests/min" }]]
        }
      },
      {
        type = "metric", x = 8, y = 6, width = 8, height = 6
        properties = {
          title   = "Latency p95, s"
          region  = var.region
          view    = "timeSeries"
          period  = 60
          metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_dim, { stat = "p95", label = "p95" }]]
        }
      },
      {
        type = "metric", x = 16, y = 6, width = 8, height = 6
        properties = {
          title  = "5xx responses"
          region = var.region
          view   = "timeSeries"
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.alb_dim, { label = "Target 5xx" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { label = "ALB 5xx" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "Database load (RDS)"
          region = var.region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.mysql.identifier, { stat = "Average", label = "RDS CPU %" }],
            [".", "DatabaseConnections", ".", ".", { stat = "Average", label = "Connections", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title  = "Cache hits / misses"
          region = var.region
          view   = "timeSeries"
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/ElastiCache", "CacheHits", "CacheClusterId", tolist(aws_elasticache_replication_group.cache.member_clusters)[0], { label = "Hits" }],
            [".", "CacheMisses", ".", ".", { label = "Misses" }],
          ]
        }
      },
      {
        type = "alarm", x = 0, y = 18, width = 24, height = 3
        properties = {
          title  = "Alarms"
          alarms = [aws_cloudwatch_metric_alarm.cpu_high.arn]
        }
      },
    ]
  })
}
