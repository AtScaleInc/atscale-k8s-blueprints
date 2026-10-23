locals {
  use_existing_vnet = var.existing_vnet_name != null

  # Subnets live in the VNet's resource group, which for an existing VNet is
  # usually a separate network RG owned by the cloud team (hub-spoke).
  vnet_resource_group_name = local.use_existing_vnet ? coalesce(var.existing_vnet_resource_group_name, var.resource_group_name) : var.resource_group_name
  vnet_name                = local.use_existing_vnet ? data.azurerm_virtual_network.existing[0].name : azurerm_virtual_network.this[0].name
  vnet_id                  = local.use_existing_vnet ? data.azurerm_virtual_network.existing[0].id : azurerm_virtual_network.this[0].id
  vnet_address_space       = local.use_existing_vnet ? data.azurerm_virtual_network.existing[0].address_space : azurerm_virtual_network.this[0].address_space
}

data "azurerm_virtual_network" "existing" {
  count               = local.use_existing_vnet ? 1 : 0
  name                = var.existing_vnet_name
  resource_group_name = local.vnet_resource_group_name
}

resource "azurerm_virtual_network" "this" {
  count               = local.use_existing_vnet ? 0 : 1
  name                = var.vnet_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    Environment = var.environment
  }
}

moved {
  from = azurerm_virtual_network.this
  to   = azurerm_virtual_network.this[0]
}

resource "azurerm_subnet" "aks-subnet" {
  name                 = "${var.environment}-aks-subnet"
  resource_group_name  = local.vnet_resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.aks_subnet_cidr]
}

# With outbound_type = userDefinedRouting, AKS validates at cluster creation
# that the node subnet already routes 0.0.0.0/0 to a gateway or NVA.
resource "azurerm_subnet_route_table_association" "aks" {
  count          = var.route_table_id != null ? 1 : 0
  subnet_id      = azurerm_subnet.aks-subnet.id
  route_table_id = var.route_table_id
}


# Dedicated subnet for the Application Gateway for Containers association.
# Required by the ALB controller add-on: it must be delegated to
# Microsoft.ServiceNetworking/trafficControllers and be at least a /24
# (>= 250 usable addresses). The add-on does not create this for a
# bring-your-own VNet, so the blueprint provisions it here.
resource "azurerm_subnet" "alb-subnet" {
  count                = var.enable_ingress_gateway ? 1 : 0
  name                 = "${var.environment}-alb-subnet"
  resource_group_name  = local.vnet_resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.alb_subnet_cidr]

  delegation {
    name = "alb-delegation"

    service_delegation {
      name = "Microsoft.ServiceNetworking/trafficControllers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}


resource "azurerm_subnet" "postgresql-subnet" {
  count                = var.enable_postgresql ? 1 : 0
  name                 = "${var.environment}-postgresql-subnet"
  resource_group_name  = local.vnet_resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.nodes_subnet_cidr]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "postgresql-delegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}


resource "azurerm_private_dns_zone" "postgresql" {
  count               = var.enable_postgresql ? 1 : 0
  name                = "${var.environment}.postgres.database.azure.com"
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_subnet_network_security_group_association.postgresql]
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  count                 = var.enable_postgresql ? 1 : 0
  name                  = "${var.environment}-postgresdns-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgresql[0].name
  virtual_network_id    = local.vnet_id
  resource_group_name   = var.resource_group_name
}
