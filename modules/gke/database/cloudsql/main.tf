# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name                = "${var.environment}-postgres"
  database_version    = var.database_version
  region              = var.region
  project             = var.project_id
  deletion_protection = false

  settings {
    tier = var.database_tier

    backup_configuration {
      enabled    = false
      start_time = "03:00"
    }

    ip_configuration {
      ipv4_enabled = true
    }
  }
}

# Create PostgreSQL Database
resource "google_sql_database" "database" {
  name     = var.database_name
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
}

# Create database user
resource "google_sql_user" "db_user" {
  name     = var.database_user
  instance = google_sql_database_instance.postgres.name
  password = random_password.database_password.result
  project  = var.project_id
}

resource "random_password" "database_password" {
  length  = 16
  special = false
}
