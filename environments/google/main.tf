# Environment Variables
# Edit this variables in order to customize all the resources in the environment, such as the VPC, GKE cluster, etc.
locals {
  ############################################################################
  # General Variables
  ############################################################################
  environment                   = "[YOUR_ENVIRONMENT_NAME]" # Replace with your environment name
  project_id                    = "[YOUR_PROJECT_ID]"       # Replace with your GCP project ID
  subnet_cidr                   = "[YOUR_SUBNET_CIDR]"      # Subnet CIDR for GKE nodes (recommended: /20 for 4096 IPs)
  pods_secondary_range_cidr     = "[YOUR_PODS_SECONDARY_RANGE_CIDR]"
  services_secondary_range_cidr = "[YOUR_SERVICES_SECONDARY_RANGE_CIDR]"
  region                        = "[YOUR_REGION]" # Replace with your region (e.g. us-central1)
  cluster_name                  = "[YOUR_CLUSTER_NAME]"
  enable_postgres_database      = true
  filestore_tier                = "BASIC_HDD" # Filestore tier (BASIC_HDD, BASIC_SSD, STANDARD, PREMIUM, ENTERPRISE)

  ############################################################################
  # GKE Variables
  ############################################################################
  k8s_version                        = "1.33"              # Replace with the Kubernetes version you want to use
  gke_instance_types                 = ["n2d-standard-16"] # Replace with the instance types you want to use, bear in mind that the instance types you choose will affect the cost of the cluster
  gke_workers_min_instance_count     = 1                   # Replace with the minimum number of worker nodes you want to use
  gke_workers_max_instance_count     = 3                   # Replace with the maximum number of worker nodes you want to use
  gke_workers_desired_instance_count = 1                   # Replace with the desired number of worker nodes you want to use
  enable_spot_instances              = true                # If you want to use spot instances (preemptible), set this to true

  ############################################################################
  # Database Variables
  ############################################################################
  database_version = "POSTGRES_15"          # PostgreSQL version
  database_tier    = "db-f1-micro"          # Database instance tier (db-f1-micro is smallest/cheapest)
  database_name    = "[YOUR_DATABASE_NAME]" # Database name
  database_user    = "[YOUR_DATABASE_USER]" # Database user
}

# VPC
################################################################################

module "vpc" {
  source                        = "../../modules/gke/networking/vpc"
  project_id                    = local.project_id
  environment                   = local.environment
  region                        = local.region
  subnet_cidr                   = local.subnet_cidr
  pods_secondary_range_cidr     = local.pods_secondary_range_cidr
  services_secondary_range_cidr = local.services_secondary_range_cidr
  enable_private_google_access  = true
}


#############################################################################
# GKE Cluster
#############################################################################

module "gke" {
  source       = "../../modules/gke/compute/gke"
  project_id   = local.project_id
  environment  = local.environment
  region       = local.region
  cluster_name = local.cluster_name
  k8s_version  = local.k8s_version

  # Network configuration from VPC module
  network                       = module.vpc.vpc_name
  subnetwork                    = module.vpc.subnet_name
  pods_secondary_range_name     = module.vpc.pods_secondary_range_name
  services_secondary_range_name = module.vpc.services_secondary_range_name

  # Node pool configuration
  node_pool_name     = "${local.environment}-gke-node-pool"
  machine_type       = local.gke_instance_types[0]
  min_node_count     = local.gke_workers_min_instance_count
  max_node_count     = local.gke_workers_max_instance_count
  initial_node_count = local.gke_workers_desired_instance_count
  preemptible        = local.enable_spot_instances

  # Enable external access (public endpoint)
  enable_private_nodes    = false
  master_ipv4_cidr_block  = "10.0.0.0/28"
  enable_private_endpoint = false

  # Filestore Parameters
  tier = local.filestore_tier

  depends_on = [module.vpc]
}


#############################################################################
# Cloud SQL PostgreSQL Database
#############################################################################

module "database" {
  count       = local.enable_postgres_database ? 1 : 0
  source      = "../../modules/gke/database/cloudsql"
  project_id  = local.project_id
  environment = local.environment
  region      = local.region

  database_version = local.database_version
  database_tier    = local.database_tier
  database_name    = local.database_name
  database_user    = local.database_user
}
