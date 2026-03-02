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

variable "project_id" {
  description = "GCP project ID"
  type        = string
  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID cannot be empty."
  }
}

variable "region" {
  description = "GCP region (e.g., us-central1, us-east1)"
  type        = string
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "Must be a valid GCP region (e.g., us-central1, europe-west1)."
  }
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cluster_name)) && length(var.cluster_name) >= 2
    error_message = "Cluster name must be lowercase alphanumeric with hyphens."
  }
}

############################################################################
# Networking Variables
#
# GKE requires three non-overlapping CIDR ranges:
#
#   subnet_cidr                   - Primary range for GKE node IPs.
#                                   Recommended: /20 (4,094 usable IPs)
#                                   Example: 10.0.0.0/20
#
#   pods_secondary_range_cidr     - Secondary range for Pod IPs. GKE assigns
#                                   a /24 per node, so this must be large.
#                                   Recommended: /16 (65,534 IPs)
#                                   Example: 10.1.0.0/16
#
#   services_secondary_range_cidr - Secondary range for Kubernetes Service
#                                   ClusterIPs. Recommended: /20 (4,094 IPs)
#                                   Example: 10.2.0.0/20
#
# None of these ranges should overlap with each other.
############################################################################

variable "subnet_cidr" {
  description = "Primary subnet CIDR for GKE nodes (recommended: /20, e.g., 10.0.0.0/20)"
  type        = string
  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.0.0.0/20)."
  }
}

variable "pods_secondary_range_cidr" {
  description = "Secondary CIDR for Pod IPs. Must be large (/16 recommended) since each node uses a /24. Example: 10.1.0.0/16"
  type        = string
  validation {
    condition     = can(cidrhost(var.pods_secondary_range_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.1.0.0/16)."
  }
}

variable "services_secondary_range_cidr" {
  description = "Secondary CIDR for Kubernetes Service ClusterIPs (recommended: /20, e.g., 10.2.0.0/20)"
  type        = string
  validation {
    condition     = can(cidrhost(var.services_secondary_range_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.2.0.0/20)."
  }
}

variable "enable_postgres_database" {
  description = "Whether to create a Cloud SQL PostgreSQL instance"
  type        = bool
  default     = true
}

variable "filestore_tier" {
  description = "Filestore tier (BASIC_HDD, BASIC_SSD, STANDARD, PREMIUM, ENTERPRISE)"
  type        = string
  default     = "BASIC_SSD"
}

############################################################################
# GKE Variables
############################################################################

variable "k8s_version" {
  description = "Kubernetes version for GKE"
  type        = string
}

variable "gke_instance_types" {
  description = "List of machine types for GKE worker nodes"
  type        = list(string)
  default     = ["n2d-standard-4"]
}

variable "gke_workers_min_instance_count" {
  description = "Minimum number of GKE worker nodes"
  type        = number
  default     = 1
}

variable "gke_workers_max_instance_count" {
  description = "Maximum number of GKE worker nodes"
  type        = number
  default     = 3
}

variable "gke_workers_desired_instance_count" {
  description = "Desired number of GKE worker nodes"
  type        = number
  default     = 1
}

variable "enable_spot_instances" {
  description = "Whether to use preemptible (spot) instances for cost savings"
  type        = bool
  default     = true
}

variable "public_api_server" {
  description = "Whether the cluster API server is publicly accessible. Set to false for a fully private cluster (requires VPN or bastion to run kubectl)."
  type        = bool
  default     = true
}

variable "authorized_network_cidr" {
  description = "CIDR block allowed to access the API server when public_api_server is false (e.g., your VPC CIDR or VPN range)."
  type        = string
  default     = ""
}

############################################################################
# Database Variables
############################################################################

variable "database_version" {
  description = "Cloud SQL PostgreSQL version"
  type        = string
  default     = "POSTGRES_16"
}

variable "database_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro"
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "postgres"
}

variable "database_user" {
  description = "Database user"
  type        = string
  default     = "postgres"
}
