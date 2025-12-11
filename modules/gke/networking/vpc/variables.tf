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
  description = "The GCP region to deploy the VPC"
  type        = string
  validation {
    condition     = length(var.region) > 0
    error_message = "Region cannot be empty."
  }
}

variable "subnet_cidr" {
  description = "The CIDR block for the subnet (recommended: /22 for GKE)"
  type        = string
  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "Subnet CIDR must be a valid CIDR block."
  }
}

variable "pods_secondary_range_cidr" {
  description = "The CIDR block for the pods secondary IP range (recommended: /14)"
  type        = string
  validation {
    condition     = can(cidrhost(var.pods_secondary_range_cidr, 0))
    error_message = "Pods secondary range CIDR must be a valid CIDR block."
  }
}

variable "services_secondary_range_cidr" {
  description = "The CIDR block for the services secondary IP range (recommended: /20)"
  type        = string
  validation {
    condition     = can(cidrhost(var.services_secondary_range_cidr, 0))
    error_message = "Services secondary range CIDR must be a valid CIDR block."
  }
}

variable "enable_private_google_access" {
  description = "Enable private Google access for the subnet"
  type        = bool
  default     = true
}

