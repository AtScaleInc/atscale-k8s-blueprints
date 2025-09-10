
output "vnet_id" {
  description = "The ID of the Virtual Network."
  value       = azurerm_virtual_network.this.id
}


output "vnet_name" {
  description = "The name of the Virtual Network."
  value       = azurerm_virtual_network.this.name
}


output "vnet_address_space" {
  description = "The address space of the Virtual Network."
  value       = azurerm_virtual_network.this.address_space
}


output "postgresql_subnet_id" {
  description = "The ID of the PostgreSQL subnet."
  value       = var.enable_postgresql ? azurerm_subnet.postgresql-subnet[0].id : null
}

output "aks_subnet_id" {
  description = "The ID of the AKS subnet."
  value       = azurerm_subnet.aks-subnet.id
}


output "postgresql_private_dns_zone_id" {

  description = "The ID of the PostgreSQL private DNS zone."
  value       = var.enable_postgresql ? azurerm_private_dns_zone.postgresql[0].id : null
}
