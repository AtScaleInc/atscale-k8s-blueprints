variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "The environment name"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy the Cloud SQL instance"
  type        = string
}

variable "database_version" {
  description = "The PostgreSQL database version"
  type        = string
  default     = "POSTGRES_15"
}

variable "database_tier" {
  description = "The machine tier for the Cloud SQL instance"
  type        = string
  default     = "db-f1-micro"
}

variable "database_name" {
  description = "The name of the database to create"
  type        = string
  default     = "postgres"
}

variable "database_user" {
  description = "The database user name"
  type        = string
  default     = "postgres"
}
