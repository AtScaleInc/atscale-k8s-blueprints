# RDS Proxy for Primary (Write operations)
data "aws_caller_identity" "current" {}

resource "aws_db_proxy" "rds_proxy" {
  count = var.enable_rds ? 1 : 0

  name                   = "${var.rds_identifier}-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.rds_proxy_role[0].arn
  idle_client_timeout    = "1800"
  vpc_subnet_ids         = var.private_subnets
  vpc_security_group_ids = [aws_security_group.rds_proxy_sg[0].id]


  auth {
    auth_scheme               = "SECRETS"
    iam_auth                  = "DISABLED"
    client_password_auth_type = "POSTGRES_MD5" # For enhanced security, consider changing to POSTGRES_SCRAM_SHA_256
    secret_arn                = aws_secretsmanager_secret.rds_credentials[0].arn
  }

  tags = merge(var.tags, {
    Name = "${var.rds_identifier}-proxy"
    Type = "write"
  })

  depends_on = [
    aws_iam_role.rds_proxy_role,
    aws_secretsmanager_secret_version.rds_credentials,
    aws_secretsmanager_secret.rds_credentials,
    aws_rds_cluster.primary
  ]
}

# RDS Proxy Target for Primary Instance 
resource "aws_db_proxy_default_target_group" "rds_proxy_primary_target_group" {
  count         = var.enable_rds ? 1 : 0
  db_proxy_name = aws_db_proxy.rds_proxy[0].name
  connection_pool_config {
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "rds_proxy_target" {
  count = var.enable_rds ? 1 : 0

  db_cluster_identifier = aws_rds_cluster.primary[0].cluster_identifier
  db_proxy_name         = aws_db_proxy.rds_proxy[0].name
  target_group_name     = aws_db_proxy_default_target_group.rds_proxy_primary_target_group[0].name
}

resource "aws_db_proxy_endpoint" "rds_proxy_endpoint" {
  count                  = var.enable_rds ? 1 : 0
  db_proxy_name          = aws_db_proxy.rds_proxy[0].name
  db_proxy_endpoint_name = "${var.rds_identifier}-proxy-ro-endpoint"
  vpc_subnet_ids         = var.private_subnets
  target_role            = "READ_ONLY"
}
