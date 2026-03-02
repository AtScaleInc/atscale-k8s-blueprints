# Private IP range for Cloud SQL VPC peering
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.environment}-cloudsql-private-ip"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_network_self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_network_self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name                = "${var.environment}-postgres"
  database_version    = var.database_version
  region              = var.region
  project             = var.project_id
  deletion_protection = var.deletion_protection

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = var.database_tier

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_network_self_link
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
