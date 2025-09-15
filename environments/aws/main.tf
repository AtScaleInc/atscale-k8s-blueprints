# Environment Variables
# Edit this variables in order to customize all the resources in the environment, such as the VPC, EKS cluster, RDS instance, etc.
locals {
  ############################################################################
  # General Variables
  ############################################################################
  environment  = "YOUR-ENVIRONMENT" # Replace with your environment name
  vpc_cidr     = "YOUR-VPC-CIDR"    # Replace with your VPC CIDR (e.g. 10.84.0.0/22)
  region       = "YOUR-REGION"      # Replace with your region (e.g. us-east-1)
  cluster_name = "${local.environment}-eks"

  ############################################################################
  # EKS Variables
  ############################################################################
  k8s_version                        = "1.32"                                               # Replace with the Kubernetes version you want to use
  eks_instance_types                 = ["m6a.4xlarge"]                                      # Replace with the instance types you want to use, bear in mind that the instance types you choose will affect the cost of the cluster
  eks_workers_min_instance_count     = 3                                                    # Replace with the minimum number of worker nodes you want to use
  eks_workers_max_instance_count     = 6                                                    # Replace with the maximum number of worker nodes you want to use
  eks_workers_desired_instance_count = 3                                                    # Replace with the desired number of worker nodes you want to use
  enable_spot_instances              = true                                                 # If you want to use spot instances, set this to true
  sso_enabled                        = false                                                # If you want to use SSO to authenticate users to the cluster, set this to true
  aws_auth_sso_users                 = [{ role = "YOUR_ROLE_NAME", arn = "YOUR_ROLE_ARN" }] # If you want to use SSO to authenticate users to the cluster, add the users you want to authenticate to the cluster here

  ############################################################################
  # RDS Variables
  ############################################################################
  enable_rds               = false            # If you want an external RDS instance, set this to true
  rds_instance_class       = "db.r6gd.xlarge" # Replace with the instance class you want to use, bear in mind that the instance class you choose will affect the cost of the RDS instance
  rds_allocated_storage    = 250              # Replace with the allocated storage you want to use
  rds_engine               = "postgres"       # Replace with the engine you want to use
  rds_engine_version       = "16.4"           # Replace with the engine version you want to use
  rds_major_engine_version = "16"             # Replace with the major engine version you want to use
  rds_db_name              = "postgres"       # Replace with the database name you want to use (e.g. postgres)
  rds_username             = "adminuser"      # Replace with the username you want to use (e.g. adminuser)
  rds_port                 = 5432             # Replace with the port you want to use (e.g. 5432)


  ############################################################################
  # Networking CIDR Variables
  # Calculated subnet CIDRs (do not edit this)
  # This will create 3 private subnets and 3 public subnets in the VPC from the VPC CIDR you provided on the locals block
  ############################################################################

  private_subnet_cidrs = [
    cidrsubnet(local.vpc_cidr, 3, 0),
    cidrsubnet(local.vpc_cidr, 3, 1),
    cidrsubnet(local.vpc_cidr, 3, 2)
  ]
  public_subnet_cidrs = [
    cidrsubnet(local.vpc_cidr, 3, 4),
    cidrsubnet(local.vpc_cidr, 3, 5),
    cidrsubnet(local.vpc_cidr, 3, 6)
  ]
}

# VPC
################################################################################

module "vpc" {
  source = "../../modules/aws/networking/vpc"

  vpc_cidr        = local.vpc_cidr
  environment     = "${local.environment}-eks-tf"
  region          = local.region
  private_subnets = local.private_subnet_cidrs
  public_subnets  = local.public_subnet_cidrs
  cluster_name    = local.cluster_name
}

# EKS
################################################################################

module "eks" {
  depends_on = [module.vpc]
  source     = "../../modules/aws/compute/eks"

  cluster_name                       = local.cluster_name
  k8s_version                        = local.k8s_version
  environment                        = local.environment
  region                             = local.region
  vpc_id                             = module.vpc.vpc_id
  private_subnets_cidr_blocks        = module.vpc.private_subnets_cidr_blocks
  private_subnets_ids                = module.vpc.private_subnets_ids
  eks_ami_type                       = "AL2023_x86_64_STANDARD"
  eks_instance_types                 = local.eks_instance_types
  enable_spot_instances              = local.enable_spot_instances
  eks_workers_min_instance_count     = local.eks_workers_min_instance_count
  eks_workers_max_instance_count     = local.eks_workers_max_instance_count
  eks_workers_desired_instance_count = local.eks_workers_desired_instance_count
  vpc_access_cidr                    = [module.vpc.vpc_cidr]

  # SSH access to the cluster
  aws_auth_sso_users = local.aws_auth_sso_users
  sso_enabled        = local.sso_enabled

  tags = {
    Environment = local.environment
    Project     = local.cluster_name
  }
}

# # On-Demand Resources (RDS, Redis, etc.)
# ################################################################################

module "on_demand_services" {
  source = "../../modules/aws/on_demand_resources"

  # RDS
  enable_rds               = local.enable_rds # If you want an external RDS instance, set this to true
  rds_identifier           = "${local.environment}-postgres"
  rds_instance_class       = local.rds_instance_class
  rds_allocated_storage    = local.rds_allocated_storage
  rds_engine               = local.rds_engine
  rds_engine_version       = local.rds_engine_version
  rds_major_engine_version = local.rds_major_engine_version
  rds_db_name              = local.rds_db_name
  rds_username             = local.rds_username
  rds_port                 = local.rds_port
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr
  private_subnets          = module.vpc.private_subnets_ids
  public_subnets           = module.vpc.public_subnets_ids
  eks_cluster_sg_id        = module.eks.cluster_security_group_id
  deletion_protection      = false
  tags = {
    Environment = local.environment
    Project     = local.cluster_name
  }
}
# }
