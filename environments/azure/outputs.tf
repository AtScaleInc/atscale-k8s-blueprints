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

# Consumed by the make target to bootstrap the default ApplicationLoadBalancer.
output "alb_subnet_id" {
  value = module.networking.alb_subnet_id
}

output "create_default_alb" {
  value = var.create_default_alb
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
