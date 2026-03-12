# RDS Multi-AZ DB Cluster
resource "aws_rds_cluster" "primary" {
  count = var.enable_rds ? 1 : 0

  cluster_identifier                  = var.rds_identifier
  engine                              = var.rds_engine
  engine_version                      = var.rds_engine_version
  db_cluster_instance_class           = var.rds_instance_class
  allocated_storage                   = var.rds_allocated_storage
  database_name                       = var.rds_db_name
  master_username                     = var.rds_username
  master_password                     = random_password.rds_password[0].result
  port                                = var.rds_port
  apply_immediately                   = true
  iam_database_authentication_enabled = false
  storage_type                        = "io2"
  iops                                = 5000
  db_cluster_parameter_group_name     = "rds-parameter-group"

  # Security and networking
  vpc_security_group_ids = [aws_security_group.rds_sg[0].id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group[0].name

  # Backup configuration
  backup_retention_period      = 1
  preferred_backup_window      = "03:00-06:00"
  preferred_maintenance_window = "Mon:00:00-Mon:03:00"

  # Snapshot settings
  skip_final_snapshot = true
  deletion_protection = var.deletion_protection

  tags = merge(var.tags, {
    Name = "${var.rds_identifier}-cluster"
    Type = "rds-multi-az-cluster"
  })
}

# DB Subnet Group for the cluster
resource "aws_db_subnet_group" "rds_subnet_group" {
  count = var.enable_rds ? 1 : 0

  name        = "${var.rds_identifier}-subnet-group"
  description = "DB subnet group for ${var.rds_identifier}"
  subnet_ids  = var.private_subnets

  tags = merge(var.tags, {
    Name = "${var.rds_identifier}-subnet-group"
  })
}

resource "random_password" "rds_password" {
  count            = var.enable_rds ? 1 : 0
  length           = 16
  special          = true
  override_special = "!#$%&*"
  lifecycle {
    ignore_changes = all
  }
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  count       = var.enable_rds ? 1 : 0
  name        = "${var.rds_identifier}-credentials-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  description = "Credentials for RDS cluster ${var.rds_identifier}"
  tags = merge(var.tags, {
    Name = "${var.rds_identifier}-credentials-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  })
  lifecycle {
    ignore_changes = all
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  count     = var.enable_rds ? 1 : 0
  secret_id = aws_secretsmanager_secret.rds_credentials[0].id
  secret_string = jsonencode({
    username = var.rds_username
    password = random_password.rds_password[0].result
  })
}
