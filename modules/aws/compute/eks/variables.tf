variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment name cannot be empty."
  }
}

variable "region" {
  description = "Region"
  type        = string
  validation {
    condition     = length(var.region) > 0
    error_message = "Region cannot be empty."
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets_cidr_blocks" {
  description = "Private subnets"
  type        = list(string)
}

variable "private_subnets_ids" {
  description = "Private subnets IDs"
  type        = list(string)
}
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
}


variable "eks_ami_type" {
  description = "EKS AMI type"
  type        = string
}

variable "eks_instance_types" {
  description = "EKS instance types"
  type        = list(string)
}

variable "eks_workers_min_instance_count" {
  description = "EKS worker min instance count"
  type        = number
}

variable "eks_workers_max_instance_count" {
  description = "EKS worker max instance count"
  type        = number
}

variable "eks_workers_desired_instance_count" {
  description = "EKS worker desired instance count"
  type        = number
}

variable "vpc_access_cidr" {
  type        = list(string)
  description = "Variable for CIDR to be applied in access security group"
}

variable "enable_spot_instances" {
  description = "Whether to use spot instances for the EKS node groups"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to be applied to the resources"
  type        = map(string)
}

variable "sso_enabled" {
  description = "Whether SSO is enabled"
  type        = bool
}

variable "aws_auth_sso_users" {
  description = "AWS SSO users"
  type        = list(object({ role = string, arn = string }))
}

variable "kms_admin_role" {
  description = "SSO role name that gets KMS key administrator access"
  type        = string
}

variable "enable_private_cluster" {
  description = "Whether to disable public access to the EKS API server endpoint"
  type        = bool
  default     = false
}
