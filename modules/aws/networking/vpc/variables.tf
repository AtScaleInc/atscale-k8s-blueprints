
variable "environment" {
  description = "The environment name"
  type        = string
  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment name cannot be empty."
  }
}


variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  validation {
    condition     = length(var.vpc_cidr) > 0
    error_message = "VPC CIDR cannot be empty."
  }
}

variable "region" {
  description = "The region to deploy the VPC"
  type        = string
  validation {
    condition     = length(var.region) > 0
    error_message = "Region cannot be empty."
  }
}

variable "private_subnets" {
  description = "The private subnets to deploy the VPC"
  type        = list(string)
}

variable "public_subnets" {
  description = "The public subnets to deploy the VPC"
  type        = list(string)
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}
