resource "aws_ecr_repository" "app" {
  name         = var.project
  force_delete = true
}