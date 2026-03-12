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
  default     = "POSTGRES_16"
}

variable "database_tier" {
  description = "The machine tier for the Cloud SQL instance"
  type        = string
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

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the Cloud SQL instance"
  type        = bool
  default     = true
}

variable "vpc_network_self_link" {
  description = "Self link of the VPC network for private IP connectivity"
  type        = string
}
