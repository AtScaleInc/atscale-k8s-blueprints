############################################################################
# General Variables
############################################################################

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.environment)) && length(var.environment) >= 2
    error_message = "Environment must be lowercase alphanumeric with hyphens, at least 2 characters."
  }
}

variable "vpc_cidr" {
  description = "VNet address space CIDR (e.g., 10.85.0.0/22)"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.85.0.0/22)."
  }
}

variable "region" {
  description = "Azure region (e.g., eastus, westus3)"
  type        = string
  validation {
    condition     = length(var.region) > 0
    error_message = "Region cannot be empty."
  }
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "Resource group name cannot be empty."
  }
}

############################################################################
# AKS Variables
############################################################################

variable "aks_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.31"
}

variable "aks_node_count" {
  description = "Number of nodes in the AKS default node pool"
  type        = number
  default     = 3
}

variable "aks_node_size" {
  description = "VM size for AKS nodes (e.g., Standard_D8s_v5)"
  type        = string
  default     = "Standard_D8s_v5"
}

variable "aad_admin_group_object_id" {
  description = "Azure AD admin group object ID for cluster access"
  type        = string
}

variable "public_api_server" {
  description = "Whether the cluster API server is publicly accessible. Set to false for a fully private cluster (requires VPN or bastion to run kubectl)."
  type        = bool
  default     = true
}

variable "authorized_network_cidr" {
  description = "CIDR block allowed to access the private API server. Used when public_api_server is false."
  type        = string
  default     = ""
}

############################################################################
# Database Variables
############################################################################

variable "enable_postgresql" {
  description = "Whether to create an Azure PostgreSQL Flexible Server instance"
  type        = bool
  default     = false
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "postgresql_sku_name" {
  description = "PostgreSQL SKU name (e.g., GP_Standard_D4ads_v5)"
  type        = string
  default     = "GP_Standard_D4ads_v5"
}

variable "postgresql_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 65536
}

variable "postgresql_backup_retention_days" {
  description = "PostgreSQL backup retention days (minimum 7)"
  type        = number
  default     = 7
  validation {
    condition     = var.postgresql_backup_retention_days >= 7
    error_message = "Backup retention days must be at least 7."
  }
}

variable "postgresql_geo_redundant_backup_enabled" {
  description = "Whether to enable geo-redundant backups"
  type        = bool
  default     = false
}

variable "postgresql_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "postgres"
}
