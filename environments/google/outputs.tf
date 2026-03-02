################################################################################
# Cluster
################################################################################

output "region" {
  value = var.region
}

output "project_id" {
  value = var.project_id
}

output "cluster_name" {
  value = var.cluster_name
}

output "cluster_get_credentials_command" {
  description = "Command to get credentials for the GKE cluster"
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
}

################################################################################
# Database
################################################################################

output "database_instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = length(module.database) > 0 ? module.database[0].instance_name : null
}

output "database_connection_name" {
  description = "The connection name for Cloud SQL Proxy"
  value       = length(module.database) > 0 ? module.database[0].instance_connection_name : null
}

output "database_public_ip" {
  description = "The public IP address of the database"
  value       = length(module.database) > 0 ? module.database[0].instance_public_ip : null
}

output "database_name" {
  description = "The database name"
  value       = length(module.database) > 0 ? module.database[0].database_name : null
}

output "database_user" {
  description = "The database user"
  value       = length(module.database) > 0 ? module.database[0].database_user : null
}

output "database_password" {
  description = "The randomly generated database password"
  value       = length(module.database) > 0 ? module.database[0].database_password : null
  sensitive   = true
}
