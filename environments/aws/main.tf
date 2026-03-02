locals {
  cluster_name = "${var.environment}-eks"

  ############################################################################
  # Networking CIDR Variables
  # Calculated subnet CIDRs (do not edit)
  # Creates 3 private subnets and 3 public subnets from the VPC CIDR
  ############################################################################
  private_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 3, 0),
    cidrsubnet(var.vpc_cidr, 3, 1),
    cidrsubnet(var.vpc_cidr, 3, 2)
  ]
  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 3, 4),
    cidrsubnet(var.vpc_cidr, 3, 5),
    cidrsubnet(var.vpc_cidr, 3, 6)
  ]
}

# VPC
################################################################################

module "vpc" {
  source = "../../modules/aws/networking/vpc"

  vpc_cidr        = var.vpc_cidr
  environment     = "${var.environment}-eks-tf"
  region          = var.region
  private_subnets = local.private_subnet_cidrs
  public_subnets  = local.public_subnet_cidrs
  cluster_name    = local.cluster_name
}

# EKS
################################################################################

module "eks" {
  source = "../../modules/aws/compute/eks"

  cluster_name                       = local.cluster_name
  k8s_version                        = var.k8s_version
  environment                        = var.environment
  region                             = var.region
  vpc_id                             = module.vpc.vpc_id
  private_subnets_cidr_blocks        = module.vpc.private_subnets_cidr_blocks
  private_subnets_ids                = module.vpc.private_subnets_ids
  eks_ami_type                       = "AL2023_x86_64_STANDARD"
  eks_instance_types                 = var.eks_instance_types
  enable_spot_instances              = var.enable_spot_instances
  eks_workers_min_instance_count     = var.eks_workers_min_instance_count
  eks_workers_max_instance_count     = var.eks_workers_max_instance_count
  eks_workers_desired_instance_count = var.eks_workers_desired_instance_count
  vpc_access_cidr                    = [module.vpc.vpc_cidr]
  enable_private_cluster             = !var.public_api_server

  aws_auth_sso_users = var.aws_auth_sso_users
  sso_enabled        = var.sso_enabled

  tags = {
    Environment = var.environment
    Project     = local.cluster_name
  }
}

# On-Demand Resources (RDS, Redis, etc.)
################################################################################

module "on_demand_services" {
  source = "../../modules/aws/on_demand_resources"

  enable_rds               = var.enable_rds
  rds_identifier           = "${var.environment}-postgres"
  rds_instance_class       = var.rds_instance_class
  rds_allocated_storage    = var.rds_allocated_storage
  rds_engine               = var.rds_engine
  rds_engine_version       = var.rds_engine_version
  rds_major_engine_version = var.rds_major_engine_version
  rds_db_name              = var.rds_db_name
  rds_username             = var.rds_username
  rds_port                 = var.rds_port
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr
  private_subnets          = module.vpc.private_subnets_ids
  public_subnets           = module.vpc.public_subnets_ids
  eks_cluster_sg_id        = module.eks.cluster_security_group_id
  deletion_protection      = true
  tags = {
    Environment = var.environment
    Project     = local.cluster_name
  }
}
