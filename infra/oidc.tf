resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "gh_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github" {
  name               = "${var.project}-github"
  assume_role_policy = data.aws_iam_policy_document.gh_trust.json
}

resource "aws_iam_role_policy" "github" {
  role = aws_iam_role.github.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow",
        Action = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload",
                  "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage",
                  "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"],
        Resource = aws_ecr_repository.app.arn },
      { Effect = "Allow",
        Action = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition",
                  "ecs:DescribeServices", "ecs:UpdateService"],
        Resource = "*" },
      { Effect = "Allow", Action = ["iam:PassRole"], Resource = aws_iam_role.task_exec.arn }
    ]
  })
}

output "github_role_arn" {
  value = aws_iam_role.github.arn
}