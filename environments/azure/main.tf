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

  # Third /24 of the /22, used for the Application Gateway for Containers
  # association subnet when the ingress gateway is enabled. A /24 gives the
  # >= 250 addresses the association requires.
  alb_subnet_cidr = cidrsubnet(var.vpc_cidr, 2, 2)

  ############################################################################
  # Minimal cluster overrides
  # A single node with no ingress gateway add-ons, so the VNet can be as
  # small as a /26 and no preview features need registering.
  ############################################################################
  aks_node_count         = var.minimal_cluster ? 1 : var.aks_node_count
  enable_ingress_gateway = var.minimal_cluster ? false : var.enable_ingress_gateway
  create_default_alb     = local.enable_ingress_gateway && var.create_default_alb

  dns_service_ip = coalesce(var.dns_service_ip, cidrhost(var.service_cidr, 10))
}

# VPC
################################################################################

module "networking" {
  source                 = "../../modules/azure/networking"
  vnet_name              = "${var.environment}-aks-vnet"
  address_space          = [var.vpc_cidr]
  location               = var.region
  resource_group_name    = var.resource_group_name
  environment            = var.environment
  nodes_subnet_cidr      = local.nodes_subnet_cidr[0]
  aks_subnet_cidr        = local.nodes_subnet_cidr[1]
  enable_postgresql      = var.enable_postgresql
  enable_ingress_gateway = local.enable_ingress_gateway
  alb_subnet_cidr        = local.alb_subnet_cidr
  route_table_id         = var.route_table_id

  existing_vnet_name                = var.existing_vnet_name
  existing_vnet_resource_group_name = var.existing_vnet_resource_group_name
  atscale_allowed_source_prefixes   = var.atscale_allowed_source_prefixes
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
  aad_admin_group_object_ids           = compact([var.aad_admin_group_object_id])
  grant_deployer_cluster_admin         = var.grant_deployer_cluster_admin
  default_node_pool_node_count         = local.aks_node_count
  default_node_pool_vm_size            = var.aks_node_size
  aks_subnet_id                        = module.networking.aks_subnet_id
  alb_subnet_id                        = module.networking.alb_subnet_id
  enable_private_cluster               = !var.public_api_server
  enable_gateway_api                   = local.enable_ingress_gateway
  enable_application_load_balancer     = local.enable_ingress_gateway
  pod_cidr                             = var.pod_cidr
  service_cidr                         = var.service_cidr
  dns_service_ip                       = local.dns_service_ip
  outbound_type                        = var.outbound_type
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
