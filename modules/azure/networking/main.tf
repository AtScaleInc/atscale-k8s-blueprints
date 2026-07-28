resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    Environment = var.environment
  }
}

resource "azurerm_subnet" "aks-subnet" {
  name                 = "${var.environment}-aks-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_cidr]
}


# Dedicated subnet for the Application Gateway for Containers association.
# Required by the ALB controller add-on: it must be delegated to
# Microsoft.ServiceNetworking/trafficControllers and be at least a /24
# (>= 250 usable addresses). The add-on does not create this for a
# bring-your-own VNet, so the blueprint provisions it here.
resource "azurerm_subnet" "alb-subnet" {
  count                = var.enable_ingress_gateway ? 1 : 0
  name                 = "${var.environment}-alb-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
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
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
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
  virtual_network_id    = azurerm_virtual_network.this.id
  resource_group_name   = var.resource_group_name
}
