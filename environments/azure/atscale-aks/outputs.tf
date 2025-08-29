output "resource_group_name" {
  value = local.resource_group_name
}

output "aks_name" {
  value = module.aks.aks_name
}

output "aks_location" {
  value = local.region
}

output "postgresql_credentials" {
  value = local.enable_postgresql ? {
    username = module.postgresql[0].server_username
    password = module.postgresql[0].server_password
    fqdn     = module.postgresql[0].server_fqdn
  } : null
  sensitive = true
}

