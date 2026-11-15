resource "aws_appautoscaling_scheduled_action" "day" {
  name               = "${var.project}-day"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = var.schedule_day_cron
  timezone           = var.schedule_timezone

  scalable_target_action {
    min_capacity = var.day_min_tasks
    max_capacity = var.autoscaling_max
  }
}

resource "aws_appautoscaling_scheduled_action" "night" {
  name               = "${var.project}-night"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = var.schedule_night_cron
  timezone           = var.schedule_timezone

  scalable_target_action {
    min_capacity = var.night_min_tasks
    max_capacity = var.autoscaling_max
  }

  depends_on = [aws_appautoscaling_scheduled_action.day]
}
