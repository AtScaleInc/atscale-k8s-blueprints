variable "server_name" {
  type        = string
  description = "The name of the PostgreSQL server"
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "location" {
  type        = string
  description = "The location of the resource group"
}

variable "postgresql_version" {
  type        = string
  description = "The version of the PostgreSQL server"
}

variable "sku_name" {
  type        = string
  description = "The SKU name of the PostgreSQL server"
}

variable "environment" {
  type        = string
  description = "The environment of the PostgreSQL server"
}

variable "administrator_login" {
  type        = string
  description = "The administrator login for the PostgreSQL server"
}

variable "storage_mb" {
  type        = number
  description = "The storage size of the PostgreSQL server"
}

variable "backup_retention_days" {
  type        = number
  description = "The backup retention days of the PostgreSQL server"
}

variable "delegated_subnet_id" {
  type        = string
  description = "The ID of the delegated subnet"
}

variable "geo_redundant_backup_enabled" {
  type        = bool
  description = "The geo redundant backup enabled of the PostgreSQL server"
}

variable "private_dns_zone_id" {
  type        = string
  description = "The ID of the private DNS zone"
}

