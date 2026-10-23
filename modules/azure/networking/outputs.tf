
output "vnet_id" {
  description = "The ID of the Virtual Network."
  value       = local.vnet_id
}


output "vnet_name" {
  description = "The name of the Virtual Network."
  value       = local.vnet_name
}


output "vnet_address_space" {
  description = "The address space of the Virtual Network."
  value       = local.vnet_address_space
}


output "postgresql_subnet_id" {
  description = "The ID of the PostgreSQL subnet."
  value       = var.enable_postgresql ? azurerm_subnet.postgresql-subnet[0].id : null
}

output "aks_subnet_id" {
  description = "The ID of the AKS subnet."
  value       = azurerm_subnet.aks-subnet.id

  # The cluster must not be created before the route table and NSG are
  # associated: AKS validates the routing, and policy denies an NSG-less subnet.
  depends_on = [
    azurerm_subnet_route_table_association.aks,
    azurerm_subnet_network_security_group_association.aks,
  ]
}

output "alb_subnet_id" {
  description = "The ID of the Application Gateway for Containers association subnet, or null when the ingress gateway is disabled."
  value       = var.enable_ingress_gateway ? azurerm_subnet.alb-subnet[0].id : null

  depends_on = [azurerm_subnet_network_security_group_association.alb]
}

output "vnet_resource_group_name" {
  description = "The resource group holding the Virtual Network and its subnets."
  value       = local.vnet_resource_group_name
}


output "postgresql_private_dns_zone_id" {

  description = "The ID of the PostgreSQL private DNS zone."
  value       = var.enable_postgresql ? azurerm_private_dns_zone.postgresql[0].id : null
}
