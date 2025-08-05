# ################################################################################
# # Cluster
# ################################################################################

output "region" {
  value = local.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

# ################################################################################
# # RDS
# ################################################################################

output "rds_credentials" {
  description = "Map containing RDS credentials and endpoint"
  value = {
    endpoint = module.on_demand_services.rds_proxy_endpoint
    database = module.on_demand_services.rds_instance_database
    username = module.on_demand_services.rds_instance_username
    password = module.on_demand_services.rds_instance_password
  }
  sensitive = true
}
