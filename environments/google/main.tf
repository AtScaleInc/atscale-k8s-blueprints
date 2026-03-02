# VPC
################################################################################

module "vpc" {
  source                        = "../../modules/gke/networking/vpc"
  project_id                    = var.project_id
  environment                   = var.environment
  region                        = var.region
  subnet_cidr                   = var.subnet_cidr
  pods_secondary_range_cidr     = var.pods_secondary_range_cidr
  services_secondary_range_cidr = var.services_secondary_range_cidr
  enable_private_google_access  = true
}


#############################################################################
# GKE Cluster
#############################################################################

module "gke" {
  source       = "../../modules/gke/compute/gke"
  project_id   = var.project_id
  environment  = var.environment
  region       = var.region
  cluster_name = var.cluster_name
  k8s_version  = var.k8s_version

  # Network configuration from VPC module
  network                       = module.vpc.vpc_name
  subnetwork                    = module.vpc.subnet_name
  pods_secondary_range_name     = module.vpc.pods_secondary_range_name
  services_secondary_range_name = module.vpc.services_secondary_range_name

  # Node pool configuration
  node_pool_name     = "${var.environment}-gke-node-pool"
  machine_type       = var.gke_instance_types[0]
  min_node_count     = var.gke_workers_min_instance_count
  max_node_count     = var.gke_workers_max_instance_count
  initial_node_count = var.gke_workers_desired_instance_count
  preemptible        = var.enable_spot_instances

  # Cluster access configuration (nodes are always private)
  master_ipv4_cidr_block  = "172.16.0.0/28"
  public_api_server       = var.public_api_server
  authorized_network_cidr = var.authorized_network_cidr

  # Filestore Parameters
  tier = var.filestore_tier

  depends_on = [module.vpc]
}


#############################################################################
# Cloud SQL PostgreSQL Database
#############################################################################

module "database" {
  count       = var.enable_postgres_database ? 1 : 0
  source      = "../../modules/gke/database/cloudsql"
  project_id  = var.project_id
  environment = var.environment
  region      = var.region

  database_version = var.database_version
  database_tier    = var.database_tier
  database_name    = var.database_name
  database_user    = var.database_user
}
