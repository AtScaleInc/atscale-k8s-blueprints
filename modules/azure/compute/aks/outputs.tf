output "aks_name" {
  value = module.aks.name
}

# The AVM module exposes no location output; the cluster is deployed into
# var.location, so surface that directly.
output "aks_location" {
  value = var.location
}
