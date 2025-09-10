# Environment Variables
# Edit this variables in order to customize all the resources in the environment, such as the VPC, AKS cluster, PostgreSQL instance, etc.
locals {
  ############################################################################
  # General Variables
  ############################################################################
  environment         = "[YOUR_ENVIRONMENT_NAME]"    # Replace with your environment name
  vpc_cidr            = "[YOUR_VPC_CIDR]"            # Replace with your VPC CIDR (e.g. 10.85.0.0/22)
  region              = "[YOUR_REGION]"              # Replace with your region (e.g. westus3)
  resource_group_name = "[YOUR_RESOURCE_GROUP_NAME]" # Replace with your resource group name

  ############################################################################
  # AKS Variables
  ############################################################################
  aks_version    = "[YOUR_KUBERNETES_VERSION]" # Replace with the Kubernetes version you want to use
  aks_node_count = "[YOUR_NODE_COUNT]"         # Replace with the number of nodes you want to use
  aks_node_size  = "[YOUR_NODE_SIZE]"          # Replace with the node size you want to use

  ############################################################################
  # Database Variables
  ############################################################################
  enable_postgresql                       = false                                     # If you want an external PostgreSQL instance, set this to true
  postgresql_version                      = "[YOUR_POSTGRESQL_VERSION]"               # Replace with the PostgreSQL version you want to use
  postgresql_sku_name                     = "[YOUR_POSTGRESQL_SKU_NAME]"              # Replace with the PostgreSQL SKU name you want to use, recommended: GP_Standard_D4ads_v5
  postgresql_storage_mb                   = "[YOUR_POSTGRESQL_STORAGE_MB]"            # Replace with the PostgreSQL storage you want to use
  postgresql_backup_retention_days        = "[YOUR_POSTGRESQL_BACKUP_RETENTION_DAYS]" # Replace with the PostgreSQL backup retention days you want to use, minimum 7
  postgresql_geo_redundant_backup_enabled = false                                     # Replace with the PostgreSQL geo-redundant backup enabled you want to use
  postgresql_admin_username               = "adminuser"                               # Replace with the PostgreSQL admin username you want to use
  aad_admin_group_object_id               = "[YOUR_AAD_ADMIN_GROUP_OBJECT_ID]"        # Replace with the AAD admin group object ID you want to use

  ############################################################################
  # Networking CIDR Variables
  # Calculated subnet CIDRs (do not edit this)
  # This will create 2 subnets in the VPC from the VPC CIDR you provided on 
  # the locals block, one for the AKS nodes and one for the PostgreSQL server
  ############################################################################
  nodes_subnet_cidr = [
    cidrsubnet(local.vpc_cidr, 2, 0),
    cidrsubnet(local.vpc_cidr, 2, 1)
  ]

}

# VPC
################################################################################

module "networking" {
  source              = "../../../modules/azure/networking"
  vnet_name           = "${local.environment}-aks-vnet"
  address_space       = [local.vpc_cidr]
  location            = local.region
  resource_group_name = local.resource_group_name
  environment         = local.environment
  nodes_subnet_cidr   = local.nodes_subnet_cidr[0]
  aks_subnet_cidr     = local.nodes_subnet_cidr[1]
  enable_postgresql   = local.enable_postgresql
}


# AKS Cluster
################################################################################

module "aks" {
  source                               = "../../../modules/azure/compute/aks"
  location                             = local.region
  environment                          = local.environment
  resource_group_name                  = local.resource_group_name
  node_resource_group_name             = "${local.environment}-aks-node-rg"
  prefix                               = local.environment
  cluster_name                         = "${local.environment}-aks"
  cluster_log_analytics_workspace_name = "${local.environment}-aks-log-analytics-workspace"
  kubernetes_version                   = local.aks_version
  aad_admin_group_object_ids           = [local.aad_admin_group_object_id]
  default_node_pool_node_count         = local.aks_node_count
  default_node_pool_vm_size            = local.aks_node_size
  aks_subnet_id                        = module.networking.aks_subnet_id
}

# Azure PostgreSQL Flexible Server
################################################################################

module "postgresql" {
  source = "../../../modules/azure/database/postgresql"

  count                        = local.enable_postgresql ? 1 : 0
  depends_on                   = [module.networking]
  location                     = local.region
  resource_group_name          = local.resource_group_name
  environment                  = local.environment
  server_name                  = "${local.environment}-postgresql-server"
  postgresql_version           = local.postgresql_version
  sku_name                     = local.postgresql_sku_name
  administrator_login          = local.postgresql_admin_username
  storage_mb                   = local.postgresql_storage_mb
  backup_retention_days        = local.postgresql_backup_retention_days
  geo_redundant_backup_enabled = local.postgresql_geo_redundant_backup_enabled
  delegated_subnet_id          = module.networking.postgresql_subnet_id
  private_dns_zone_id          = module.networking.postgresql_private_dns_zone_id
}


