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
  description = "VPC CIDR block (e.g., 10.84.0.0/22)"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g., 10.84.0.0/22)."
  }
}

variable "region" {
  description = "AWS region (e.g., us-east-1, us-west-2)"
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "Must be a valid AWS region (e.g., us-east-1, eu-west-2)."
  }
}

############################################################################
# EKS Variables
############################################################################

variable "k8s_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.34"
}

variable "eks_instance_types" {
  description = "List of EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["m6a.4xlarge", "m6i.4xlarge", "m5.4xlarge"]
}

variable "eks_workers_min_instance_count" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 3
  validation {
    condition     = var.eks_workers_min_instance_count >= 1
    error_message = "Minimum instance count must be at least 1."
  }
}

variable "eks_workers_max_instance_count" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 6
  validation {
    condition     = var.eks_workers_max_instance_count >= 1
    error_message = "Maximum instance count must be at least 1."
  }
}

variable "eks_workers_desired_instance_count" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 3
  validation {
    condition     = var.eks_workers_desired_instance_count >= 1
    error_message = "Desired instance count must be at least 1."
  }
}

variable "enable_spot_instances" {
  description = "Whether to use EC2 spot instances for cost savings. Disable if facing availability issues."
  type        = bool
  default     = true
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

variable "sso_enabled" {
  description = "Whether to enable SSO authentication for cluster access"
  type        = bool
  default     = false
}

variable "aws_auth_sso_users" {
  description = "List of SSO users to grant cluster access"
  type = list(object({
    role = string
    arn  = string
  }))
  default = []
}

variable "kms_admin_role" {
  description = "SSO role name that gets KMS key administrator access"
  type        = string
  default     = "devops"
}

############################################################################
# RDS Variables
############################################################################

variable "enable_rds" {
  description = "Whether to create an RDS PostgreSQL instance"
  type        = bool
  default     = false
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6gd.xlarge"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 250
}

variable "rds_engine" {
  description = "RDS database engine"
  type        = string
  default     = "postgres"
}

variable "rds_engine_version" {
  description = "RDS PostgreSQL engine version"
  type        = string
  default     = "16.11"
}

variable "rds_major_engine_version" {
  description = "RDS PostgreSQL major engine version"
  type        = string
  default     = "16"
}

variable "rds_db_name" {
  description = "RDS database name"
  type        = string
  default     = "postgres"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
}

variable "rds_port" {
  description = "RDS database port"
  type        = number
  default     = 5432
}
