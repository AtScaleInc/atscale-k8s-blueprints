################################################################################
# Cluster
################################################################################

output "region" {
  value = var.region
}

output "resource_group_name" {
  value = var.resource_group_name
}

output "aks_name" {
  value = module.aks.aks_name
}

################################################################################
# Database
################################################################################

output "postgresql_credentials" {
  value = var.enable_postgresql ? {
    username = module.postgresql[0].server_username
    password = module.postgresql[0].server_password
    fqdn     = module.postgresql[0].server_fqdn
  } : null
  sensitive = true
}
