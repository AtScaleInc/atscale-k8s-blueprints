locals {
  cluster_name = "${var.environment}-aks"

  ############################################################################
  # Networking CIDR Variables
  # Calculated subnet CIDRs (do not edit)
  # Creates 2 subnets: one for AKS nodes and one for the PostgreSQL server
  ############################################################################
  nodes_subnet_cidr = [
    cidrsubnet(var.vpc_cidr, 2, 0),
    cidrsubnet(var.vpc_cidr, 2, 1)
  ]
}

# VPC
################################################################################

module "networking" {
  source              = "../../modules/azure/networking"
  vnet_name           = "${var.environment}-aks-vnet"
  address_space       = [var.vpc_cidr]
  location            = var.region
  resource_group_name = var.resource_group_name
  environment         = var.environment
  nodes_subnet_cidr   = local.nodes_subnet_cidr[0]
  aks_subnet_cidr     = local.nodes_subnet_cidr[1]
  enable_postgresql   = var.enable_postgresql
}


# AKS Cluster
################################################################################

module "aks" {
  source                               = "../../modules/azure/compute/aks"
  location                             = var.region
  environment                          = var.environment
  resource_group_name                  = var.resource_group_name
  node_resource_group_name             = "${var.environment}-aks-node-rg"
  prefix                               = var.environment
  cluster_name                         = local.cluster_name
  cluster_log_analytics_workspace_name = "${var.environment}-aks-log-analytics-workspace"
  kubernetes_version                   = var.aks_version
  aad_admin_group_object_ids           = [var.aad_admin_group_object_id]
  default_node_pool_node_count         = var.aks_node_count
  default_node_pool_vm_size            = var.aks_node_size
  aks_subnet_id                        = module.networking.aks_subnet_id
  enable_private_cluster               = !var.public_api_server
}

# Azure PostgreSQL Flexible Server
################################################################################

module "postgresql" {
  source = "../../modules/azure/database/postgresql"

  enable_postgresql            = var.enable_postgresql
  count                        = var.enable_postgresql ? 1 : 0
  location                     = var.region
  resource_group_name          = var.resource_group_name
  environment                  = var.environment
  server_name                  = "${var.environment}-postgresql-server"
  postgresql_version           = var.postgresql_version
  sku_name                     = var.postgresql_sku_name
  administrator_login          = var.postgresql_admin_username
  storage_mb                   = var.postgresql_storage_mb
  backup_retention_days        = var.postgresql_backup_retention_days
  geo_redundant_backup_enabled = var.postgresql_geo_redundant_backup_enabled
  delegated_subnet_id          = var.enable_postgresql ? module.networking.postgresql_subnet_id : ""
  private_dns_zone_id          = var.enable_postgresql ? module.networking.postgresql_private_dns_zone_id : ""
}
