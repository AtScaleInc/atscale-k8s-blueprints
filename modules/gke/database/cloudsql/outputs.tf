output "instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.name
}

output "instance_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.connection_name
}

output "instance_public_ip" {
  description = "The public IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.postgres.public_ip_address
}

output "database_name" {
  description = "The name of the database"
  value       = google_sql_database.database.name
}

output "database_user" {
  description = "The database user name"
  value       = google_sql_user.db_user.name
}

output "database_password" {
  description = "The randomly generated database password"
  value       = random_password.database_password.result
  sensitive   = true
}
