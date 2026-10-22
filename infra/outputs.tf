output "app_url" {
  value = "http://${aws_lb.main.dns_name}"
}
output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}
output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}
output "ecs_service" {
  value = aws_ecs_service.app.name
}
output "db_endpoint" {
  value = aws_db_instance.mysql.address
}