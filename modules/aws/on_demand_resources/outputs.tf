output "rds_proxy_endpoint" {

  description = "The address of the primary RDS instance"
  value       = var.enable_rds ? aws_db_proxy.rds_proxy[0].endpoint : null
}

output "rds_instance_database" {
  description = "The database name of the primary RDS instance"
  value       = var.enable_rds ? aws_rds_cluster.primary[0].database_name : null
}

output "rds_instance_username" {
  description = "The username of the primary RDS instance"
  value       = var.enable_rds ? aws_rds_cluster.primary[0].master_username : null
}

output "rds_instance_password" {
  description = "The password of the primary RDS instance"
  value       = var.enable_rds ? aws_rds_cluster.primary[0].master_password : null
}
