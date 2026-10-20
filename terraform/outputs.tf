output "alb_url"      { value = "http://${aws_lb.main.dns_name}" }
output "ecr_repo"     { value = aws_ecr_repository.app.repository_url }
output "github_role"  { value = aws_iam_role.github.arn }