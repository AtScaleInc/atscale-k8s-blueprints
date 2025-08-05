# General
variable "enable_rds" {
  description = "Whether to enable the RDS module."
  type        = bool
}

variable "vpc_id" {
  description = "The ID of the VPC to create the RDS instance in."
  type        = string
}

# RDS

variable "rds_db_name" {
  description = "The name of the database to create on the RDS instance."
  type        = string
}

variable "rds_identifier" {
  description = "The identifier for the RDS instance."
  type        = string
}

variable "rds_port" {
  description = "The port for the RDS instance."
  type        = number
}

variable "rds_instance_class" {
  description = "The instance class for the RDS instance."
  type        = string
}

variable "rds_allocated_storage" {
  description = "The allocated storage for the RDS instance in GiB."
  type        = number
}

variable "rds_engine" {
  description = "The database engine for the RDS instance."
  type        = string
}

variable "rds_engine_version" {
  description = "The engine version for the RDS instance."
  type        = string
}

variable "rds_major_engine_version" {
  description = "The major engine version for the RDS instance."
  type        = string
}

variable "rds_username" {
  description = "The master username for the RDS instance."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to the RDS instance."
  type        = map(string)
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection for the RDS instance."
  type        = bool
}

# EKS related variables

variable "eks_cluster_sg_id" {
  description = "The ID of the EKS cluster security group."
  type        = string
}

variable "private_subnets" {
  description = "EKS Private Subnets"
  type        = list(string)
}

variable "public_subnets" {
  description = "EKS Public Subnets"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}
