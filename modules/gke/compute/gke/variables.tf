variable "project_id" {
  description = "The GCP project ID"
  type        = string
  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID cannot be empty."
  }
}

variable "environment" {
  description = "The environment name"
  type        = string
  default     = ""
}

variable "region" {
  description = "The GCP region to deploy the GKE cluster"
  type        = string
  validation {
    condition     = length(var.region) > 0
    error_message = "Region cannot be empty."
  }
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Cluster name cannot be empty."
  }
}

variable "k8s_version" {
  description = "The Kubernetes version to use"
  type        = string
  default     = null
}

variable "network" {
  description = "The VPC network name or self link"
  type        = string
}

variable "subnetwork" {
  description = "The subnet name or self link"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "The name of the pods secondary IP range"
  type        = string
}

variable "services_secondary_range_name" {
  description = "The name of the services secondary IP range"
  type        = string
}

variable "node_pool_name" {
  description = "The name of the node pool"
  type        = string
}

variable "machine_type" {
  description = "The machine type for the node pool"
  type        = string
  default     = "n1-standard-4"
}

variable "min_node_count" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 3
}

variable "initial_node_count" {
  description = "Initial number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "preemptible" {
  description = "Whether to use preemptible (spot) instances"
  type        = bool
  default     = false
}

variable "public_api_server" {
  description = "Whether the cluster API server is publicly accessible. Set to false for a fully private cluster (requires VPN or bastion to run kubectl)."
  type        = bool
  default     = true
}

variable "authorized_network_cidr" {
  description = "CIDR block allowed to access the private API server. Required when public_api_server is false."
  type        = string
  default     = ""
}

variable "master_ipv4_cidr_block" {
  description = "The CIDR block for the master endpoint"
  type        = string
}

variable "tier" {
  description = "The service tier for Filestore instances (BASIC_HDD, BASIC_SSD, STANDARD, PREMIUM, ENTERPRISE)"
  type        = string
  validation {
    condition     = contains(["BASIC_HDD", "BASIC_SSD", "STANDARD", "PREMIUM", "ENTERPRISE"], var.tier)
    error_message = "Valid values for tier are: BASIC_HDD, BASIC_SSD, STANDARD, PREMIUM, ENTERPRISE"
  }
}
