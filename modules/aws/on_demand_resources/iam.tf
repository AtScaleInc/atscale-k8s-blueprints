# IAM Role for RDS Proxy
resource "aws_iam_role" "rds_proxy_role" {
  count = var.enable_rds ? 1 : 0
  name  = "${var.rds_identifier}-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "rds_proxy_role_policy" {
  count = var.enable_rds ? 1 : 0
  name  = "${var.rds_identifier}-proxy-role-policy"
  role  = aws_iam_role.rds_proxy_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.rds_credentials[0].arn
      }
    ]
  })
}
